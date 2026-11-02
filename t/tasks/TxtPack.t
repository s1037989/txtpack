use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::Mojo;
use Test::More;
use TxtPack::Task::TxtPack;
use TxtPack::Test;

{
  package TxtPack::Test::Task;
  use Mojo::Base 'TxtPack::Task::TxtPack', -signatures;

  sub retry ($self, $options) {
    $self->{retry_options} = $options;
    return $self;
  }
}

my $t      = Test::Mojo->new;
my $minion = TxtPack::Test::Minion->new(locked => 1);
my $job    = TxtPack::Test::Task->new(id => 31, minion => $minion, task => 'pack_modules');

$job->run('perl-5.44.0', 'Mojo::UserAgent');

$t->test('is', $job->{retry_options}{delay}, 30, 'retries when another pack job holds the lock');

done_testing();