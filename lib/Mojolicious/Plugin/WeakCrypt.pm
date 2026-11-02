package Mojolicious::Plugin::WeakCrypt;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Digest::SHA;
use Mojo::Util qw(secure_compare);

sub register ($self, $app, $conf) {
  $app->helper('weak.decrypt' => \&_decrypt);
  $app->helper('weak.encrypt' => \&_encrypt);
}

sub _decrypt ($c, $signed_ciphertext) {
  my ($ciphertext, $signature) = split /--/, $signed_ciphertext;
  return '' unless $ciphertext && $signature;
  my $secret;
  my $secrets = $c->app->secrets;
  for (@$secrets) {
    my $check = Digest::SHA::hmac_sha256_hex($ciphertext, $_);
    $secret = $_ and last if secure_compare($signature, $check);
  }
  $c->log->trace('Token has a bad signature') and return '' unless $secret;
  my @key = split //, $secret;
  my @ct = split //, $ciphertext;
  my ($chunknum, $plaintext) = (0);
  while (@ct) {
    my $length = shift @ct;
    my $chunk = join '', splice @ct, 0, $length;
    $plaintext .= chr($chunk / ord($key[$chunknum++%$#key]));
  }
  return $plaintext;
}

sub _encrypt ($c, $plaintext) {
  return '' unless $plaintext;
  my $secret = $c->app->secrets->[0];
  my @key = split //, $secret;
  my @pt = split //, $plaintext;
  my $ciphertext;
  for (0..$#pt) {
    my $chunk = ord($pt[$_]) * ord($key[$_%$#key]);
    $ciphertext .= length($chunk).$chunk;
  }
  return join '--', $ciphertext, Digest::SHA::hmac_sha256_hex($ciphertext, $secret);
}

1;