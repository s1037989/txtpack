use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t, $minion) = TxtPack::Test->new_app('TxtPack::Application::Web');
$minion->jobs->{8} = TxtPack::Test::Job->new(info_data => {
  args  => ['perl-5.44.0', 'Mojo::JSON'],
  notes => {summary => 'JSON **works**'},
  state => 'finished',
  task  => 'pack_modules',
});

$t->app->routes->get('/test-status/:id' => sub ($c) {
  $c->render_later;
  $c->txtpack->status_p($c->param('id'))->then(sub {
    $c->render(json => {state => $c->stash('state'), summary => $c->stash('summary')});
  });
});

$t->get_ok('/test-status/8')
  ->status_is(200)
  ->json_is('/state' => 'finished')
  ->json_like('/summary' => qr/<strong>works<\/strong>/);
$t->test('is', $minion->jobs->{8}->info->{notes}{summary}, 'JSON **works**', 'stores the original summary as a job note');

done_testing();