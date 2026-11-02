package TxtPack::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::File qw(path);
use Mojo::Util qw(class_to_path decamelize);

has log => sub ($self) {
  my $log = $self->app->renderer->get_helper('log')->($self);
  $log->context(sprintf 'controller=%s', decamelize path(class_to_path(ref $self))->basename('.pm'));
};

1;