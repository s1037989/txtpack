package TxtPack::Plugin;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has 'log' => sub { Mojo::Log->new(level => 'debug') };
has name => sub ($self) { (ref($self) =~ /::(\w+)$/)[0] };

sub register ($self, $app, $conf) {
  $self->log($app->log->context(sprintf 'plugin=%s', $self->name));
  return ($self, $app, $conf);
}

1;