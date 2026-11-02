use Mojo::Base -strict, -signatures;

use Mojolicious;
use Test::Mojo;
use Test::More;

my $app = Mojolicious->new(secrets => ['test-secret']);
$app->plugin('WeakCrypt');
$app->routes->get('/crypt/:value' => sub ($c) {
  my $token = $c->weak->encrypt($c->param('value'));
  $c->render(json => {token => $token, plaintext => $c->weak->decrypt($token), tampered => $c->weak->decrypt("$token-x")});
});
my $t = Test::Mojo->new($app);

$t->get_ok('/crypt/mojo')
  ->status_is(200)
  ->json_is('/plaintext' => 'mojo')
  ->json_is('/tampered' => '')
  ->json_like('/token' => qr/--[0-9a-f]{64}\z/);

done_testing();