use Mojo::Base -strict;

use Mojo::DigitalOcean::Agent::Error;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new;
my $error = Mojo::DigitalOcean::Agent::Error->new('agent request failed')
  ->type('http')->status(503)->retry_after('10');

$t->test('is', $error->type, 'http', 'stores the error type');
$t->test('is', $error->status, 503, 'stores the HTTP status');
$t->test('is', $error->retry_after, '10', 'stores Retry-After');
$t->test('like', "$error", qr/^agent request failed\n?\z/, 'stringifies to the safe summary');

done_testing();