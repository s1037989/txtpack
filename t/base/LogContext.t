use Mojo::Base -strict;

use Mojo::Log;
use Mojo::Log::Role::Context;
use Test::Mojo;
use Test::More;

my $t   = Test::Mojo->new;
my $log = Mojo::Log->new->with_roles('+Context');
my $context = $log->context('request=abc', 'controller=txtpack', {job => 12});

$t->test('is_deeply', [map { $_->key_value } @{$context->{context}}],
  ['request=abc', 'controller=txtpack', 'job=12'], 'parses and preserves ordered context values');
$t->test('is', "" . Mojo::Log::Context->new('worker'), '[worker]', 'stringifies a context value');

done_testing();