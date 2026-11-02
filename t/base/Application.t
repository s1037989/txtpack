use Mojo::Base -strict;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t) = TxtPack::Test->new_app('TxtPack');

$t->test('is', $t->app->moniker, 'txtpack', 'sets the application moniker');
$t->test('ok', scalar(grep { $_ eq 'TxtPack::Plugin' } @{$t->app->plugins->namespaces}),
  'registers the application plugin namespace');
$t->test('ok', scalar(grep { $_ eq 'TxtPack::Controller' } @{$t->app->routes->namespaces}),
  'registers the application controller namespace');
$t->test('is', $t->app->secrets->[0], 'test-secret', 'uses the supplied test secret');

done_testing();