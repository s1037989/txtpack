package TxtPack::Test::Minion;
use Mojo::Base -base;

has tasks    => sub { {} };
has jobs     => sub { {} };
has enqueued => sub { [] };
has next_id  => 23;
has locked   => 0;

sub add_task {
  my ($self, $name, $task) = @_;
  $self->tasks->{$name} = $task;
  return $self;
}

sub enqueue {
  my ($self, $task, $args) = @_;
  push @{$self->enqueued}, {task => $task, args => $args};
  return $self->next_id;
}

sub job { return $_[0]->jobs->{$_[1]} }

sub guard { return $_[0]->locked ? undef : bless {}, 'TxtPack::Test::Guard' }

package TxtPack::Test::Job;
use Mojo::Base -base;

has info_data => sub { {} };
has notes     => sub { {} };

sub info { return $_[0]->info_data }

sub note {
  my ($self, $key, $value) = @_;
  $self->notes->{$key} = $value;
  $self->info_data->{notes}{$key} = $value;
  return $self;
}

package TxtPack::Test;
use Mojo::Base -strict;

use Test::Mojo;
use Mojolicious::Plugin::Minion;

sub new_app {
  my ($class, $app_class, $config) = @_;
  $config ||= {};
  my $minion = TxtPack::Test::Minion->new;
  my %config = (
    pg      => 'postgresql://test@127.0.0.1/txtpack_test',
    agent   => {endpoint => 'https://agent.example.test', api_key => 'test-key'},
    secrets => ['test-secret'],
    %$config,
  );

  no warnings 'redefine';
  local *Mojolicious::Plugin::Minion::register = sub {
    my ($self, $app, $plugin_config) = @_;
    $app->helper(minion => sub { $minion });
    return $minion;
  };

  my $t = Test::Mojo->new($app_class, \%config);
  return ($t, $minion);
}

package TxtPack::Test::Controller;
use Mojo::Base 'TxtPack::Controller';

our $last_log;

1;