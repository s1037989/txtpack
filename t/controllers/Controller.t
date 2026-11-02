use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t) = TxtPack::Test->new_app('TxtPack');
$t->app->routes->get('/controller-log' => sub ($c) {
  bless $c, 'TxtPack::Test::Controller';
  $TxtPack::Test::Controller::last_log = $c->log;
  $c->render(text => 'controller log created');
});

$t->get_ok('/controller-log')
  ->status_is(200)
  ->content_is('controller log created');
$t->test('ok', $TxtPack::Test::Controller::last_log->isa('Mojo::Log'), 'returns a contextual Mojo logger');
$t->test('ok', scalar(grep { $_->key eq 'controller' } @{$TxtPack::Test::Controller::last_log->{context}}),
  'adds the controller name to log context');

done_testing();