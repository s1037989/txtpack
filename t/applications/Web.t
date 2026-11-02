use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t, $minion) = TxtPack::Test->new_app('TxtPack::Application::Web');

$t->get_ok('/')
  ->status_is(200)
  ->element_exists('form[action="/pack"]')
  ->element_exists('textarea[name="modules"]');

$t->post_ok('/pack' => form => {modules => " \n\t\n"})
  ->status_is(400)
  ->content_is("Please provide at least one module.\n");

$t->post_ok('/pack' => form => {modules => "Mojo::UserAgent\n-unsafe\n"})
  ->status_is(400)
  ->content_like(qr/Invalid module name/);

$t->post_ok('/pack' => form => {modules => " Mojo::UserAgent \n\nMojolicious\n"})
  ->status_is(302)
  ->header_is(Location => '/jobs/23');

$t->test('is', $minion->enqueued->[0]{task}, 'pack_modules', 'enqueues the pack task');
$t->test('is_deeply', $minion->enqueued->[0]{args}, ['perl-5.44.0', 'Mojo::UserAgent', 'Mojolicious'],
  'trims and filters module names');
$t->test('ok', $t->app->routes->find('status_txtpack_ws')->is_websocket, 'registers the status WebSocket route');

done_testing();