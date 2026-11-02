use Mojo::Base -strict;

use Mojolicious;
use Test::Mojo;
use Test::More;

my $app = Mojolicious->new;
$app->plugin(DigitalOceanAgent => {
  endpoint => 'https://agent.example.test/api',
  api_key  => 'test-key',
  helper   => 'test_agent',
});
my $t = Test::Mojo->new($app);

$t->test('is', $t->app->test_agent->endpoint->to_string,
  'https://agent.example.test/api/v1/chat/completions?agent=true', 'registers the configured client helper');

my $error;
eval { $t->app->plugin(DigitalOceanAgent => {endpoint => 'https://agent.example.test', api_key => 'test-key', helper => 'bad-name'}) };
$error = $@;
$t->test('like', $error, qr/Invalid DigitalOceanAgent helper name/, 'rejects invalid helper names');

done_testing();