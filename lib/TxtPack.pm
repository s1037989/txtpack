package TxtPack;
use Mojo::Base 'Mojolicious', -signatures;

use Mojo::Pg;
use TxtPack::Util qw(generate_secret);

our $VERSION = '0.01';

has debug => 0;
has name => sub ($self) { (ref($self) =~ /::(\w+)$/)[0] };
has trace => 0;

sub minion { $_[0]->renderer->get_helper('minion') and $_[0]->renderer->get_helper('minion')->($_[0]) }

# This method will run once at server start
sub startup ($self) {
  # Initialize the application
  $self->moniker('txtpack');
  push @{$self->commands->namespaces}, 'TxtPack::Command';
  push @{$self->plugins->namespaces},  'TxtPack::Plugin';
  push @{$self->routes->namespaces},   'TxtPack::Controller';

  # Load configuration from config file
  my $config = $self->plugin('NotYAMLConfig');

  # Configure the application
  $self->secrets($config->{secrets} or generate_secret($self->home));
  $self->log($self->log->with_roles('+Context')->context(sprintf 'application=%s', $self->name));

  $self->helper(log => \&_log);
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($config->{pg}) });

  return $self;
}

sub _log { $_[0]->stash->{'mojo.log'} ||= $_[0]->app->log->context($_[0]->req->request_id) }

1;