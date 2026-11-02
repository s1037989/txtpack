use Mojo::Base -strict, -signatures;

use Mojo::DigitalOcean::Agent;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new;
my $agent = Mojo::DigitalOcean::Agent->new(
  endpoint => 'https://agent.example.test/api',
  api_key  => 'test-key',
  defaults => {max_tokens => 128},
);

$t->test('is', $agent->endpoint->to_string,
  'https://agent.example.test/api/v1/chat/completions?agent=true', 'normalizes the agent endpoint');
$t->test('is_deeply', $agent->_payload({messages => [{role => 'user', content => 'hello'}]}), {
  model => 'ignored', max_tokens => 128, stream => Mojo::JSON::false,
  messages => [{role => 'user', content => 'hello'}],
}, 'merges defaults into the chat payload and disables streaming');

my $error;
$agent->chat_p({stream => 1})->catch(sub ($err) { $error = $err })->wait;
$t->test('is', $error->type, 'validation', 'rejects unsupported streaming requests');

done_testing();