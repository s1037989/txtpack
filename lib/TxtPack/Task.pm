package TxtPack::Task;
use Mojo::Base 'Minion::Job', -signatures;

use Mojo::Util qw(decode);
use TxtPack::Util;

has debug => 0;
has log => sub ($self) { $self->app->log->context('task='.$self->task, 'job='.$self->id) };
has name => sub ($self) { (ref($self) =~ /::(\w+)$/)[0] };
has trace => 0;

sub run ($self, $perl, @modules) {
  return ($self, $perl, @modules);
}

1;