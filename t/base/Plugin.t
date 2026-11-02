use Mojo::Base -strict;

use Mojolicious;
use Mojo::Log::Role::Context;
use Test::Mojo;
use Test::More;
use TxtPack::Plugin;

my $t   = Test::Mojo->new;
my $app = Mojolicious->new;
$app->log(Mojo::Log->new->with_roles('+Context'));
{
	package TxtPack::Test::ExamplePlugin;
	use Mojo::Base 'TxtPack::Plugin';
}
my $plugin = TxtPack::Test::ExamplePlugin->new;
my $config = {trace => 1};
my ($returned_plugin, $returned_app, $returned_config) = $plugin->register($app, $config);

$t->test('is', $plugin->name, 'ExamplePlugin', 'derives the plugin name from its class');
$t->test('is', $returned_plugin, $plugin, 'returns itself from register');
$t->test('is', $returned_app, $app, 'returns the app from register');
$t->test('is', $returned_config, $config, 'returns the plugin config from register');
$t->test('ok', $plugin->log->isa('Mojo::Log'), 'creates a contextual logger during registration');

done_testing();