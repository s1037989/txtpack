package TxtPack::Plugin::Timers;
use Mojo::Base 'TxtPack::Plugin', -signatures;

sub register {
  my ($self, $app, $conf) = shift->SUPER::register(@_);
  $self->trace(1) if $conf->{trace};
  $app->helper('timers.add'  => sub { $self->_add(@_) });
  $app->helper('timers.busy' => sub { $self->_busy(@_) });
  $app->helper('timers.stop' => sub { $self->_stop(@_) });
}

sub _add ($self, $c, $id, $timer) {
  $c->log->trace("Adding timer for $id:$timer") if $self->trace;
  $c->stash(_key($id) => [$timer, 0]);
}

sub _busy ($self, $c, $id, $set=undef) {
  return unless my $stash = $c->stash(_key($id));
  my $timer = $stash->[0] or return;
  if (defined $set) {
    $c->log->trace("Setting timer $id:$timer to " . ($set ? 'busy' : 'not busy')) if $self->trace;
    $c->stash(_key($id))->[1] = $set;
  }
  my $busy = $c->stash(_key($id))->[1];
  $c->log->trace(sprintf "$id:$timer is %sbusy", $busy ? '' : 'not ') if $self->trace;
  return $busy;
}

sub _stop ($self, $c) {
  if ( my @timers = grep { $_ } map { /plugin\.timers\.(\w+)$/; $1 } grep { /plugin\.timers\./ } keys %{$c->stash}) {
    $c->log->trace("Stopping timers") if $self->trace;
    foreach my $id (@timers) {
      my $stash = delete $c->stash->{_key($id)};
      my $timer = $stash->[0];
      Mojo::IOLoop->remove($timer);
      $c->log->trace("Stopped timer $id:$timer") if $self->trace;
    }
  }
  return if !$c->tx || $c->tx->is_finished;
  $c->finish(1000 => "Connection intentionally closed");
}

sub _key { "plugin.timers.$_[0]" }

1;