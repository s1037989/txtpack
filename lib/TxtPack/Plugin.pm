package TxtPack::Plugin;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has app => undef, weak => 1;
has debug => 0;
has log => sub { $_[0]->app->log->context(sprintf 'plugin=%s', $_[0]->name) };
has name => sub ($self) { (ref($self) =~ /::(\w+)$/)[0] };
has trace => 0;

sub register ($self, $app, $conf) {
  $self->app($app);
  return ($self, $app, $conf);
}

1;