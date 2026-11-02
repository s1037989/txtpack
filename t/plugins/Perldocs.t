use Mojo::Base -strict;

use lib 't/lib';
use MCP::Client;
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t) = TxtPack::Test->new_app('TxtPack::Application::Web');
my $client = MCP::Client->new(ua => $t->ua, url => $t->ua->server->url->path('/mcp'));
my $result = $client->call_tool('perldocs', {module => 'Mojo::JSON'});

$t->test('like', $result->{content}[0]{text}, qr/Minimalistic JSON/, 'looks up local Perl module documentation');

done_testing();