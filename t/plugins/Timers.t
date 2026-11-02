use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t) = TxtPack::Test->new_app('TxtPack::Application::Web');
$t->app->routes->get('/test/timers' => sub ($c) {
  $c->timers->add('job-1' => 999_999);
  my $initial = $c->timers->busy('job-1') // 0;
  $c->timers->busy('job-1' => 1);
  my $busy = $c->timers->busy('job-1');
  $c->timers->busy('job-1' => 0);
  my $idle = $c->timers->busy('job-1');
  $c->render(json => {initial => $initial, busy => $busy, idle => $idle});
});

$t->get_ok('/test/timers')
  ->status_is(200)
  ->json_is({initial => 0, busy => 1, idle => 0});

done_testing();