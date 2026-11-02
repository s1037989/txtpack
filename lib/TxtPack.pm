package TxtPack;
use Mojo::Base 'Mojolicious', -signatures;

use Mojo::Pg;
use TxtPack::Util qw(generate_secret);

our $VERSION = '0.01';

# This method will run once at server start
sub startup ($self) {
  # Initialize the application
  my $app = $self->app;
  $app->moniker('txtpack');
  push @{$app->commands->namespaces}, 'TxtPack::Command';
  push @{$app->plugins->namespaces},  'TxtPack::Plugin';
  push @{$app->routes->namespaces},   'TxtPack::Controller';

  # Load configuration from config file
  my $config = $self->plugin('NotYAMLConfig');

  # Configure the application
  $self->secrets($config->{secrets} or generate_secret($self->home));
  $app->log($app->log->with_roles('+Context'));

  my $pg = Mojo::Pg->new($config->{pg});
  $self->plugin(Minion => {Pg => $pg});
  $self->plugin(DigitalOceanAgent => $config->{agent});

  $self->helper(log => \&_log);

  return $self;
}

sub _log { $_[0]->stash->{'mojo.log'} ||= $_[0]->app->log->context($_[0]->req->request_id) }

1;