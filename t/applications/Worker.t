use Mojo::Base -strict;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t, $minion) = TxtPack::Test->new_app('TxtPack::Application::Worker');

$t->test('is', $t->app->moniker, 'txtpack', 'uses the application moniker');
$t->test('is', $minion->tasks->{pack_modules}, 'TxtPack::Task::TxtPack', 'registers the pack task');

done_testing();