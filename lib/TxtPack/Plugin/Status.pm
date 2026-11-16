package TxtPack::Plugin::Status;
use Mojo::Base 'TxtPack::Plugin', -signatures;

use Markdown::Simple;

sub register {
  my ($self, $app, $conf) = shift->SUPER::register(@_);
  $self->trace(1) if $conf->{trace};
  $app->helper('txtpack.status_p' => sub { $self->_status_p(@_) });
}

sub _status_p ($self, $c, $id, $stop=undef) {
  return Mojo::Promise->resolve if $c->timers->busy($id);
  $c->timers->busy($id => 1);
  my $job      = $c->app->minion->job($id);
  my $info     = $job ? $job->info : undef;
  my $state    = $info->{state} // 'unknown';
  my $finished = $state eq 'finished' || $state eq 'failed';
  my $module   = $info->{args}[1] // 'unknown';
  my $summary  = $c->stash('summary') || $info->{notes}{summary} // '';
  $c->stash(info => $info, state => $state, summary => $summary);
  my $websocket = $c->tx && $c->tx->is_websocket && !$c->tx->is_finished;

  Mojo::Promise->resolve->then(sub {
    $c->log->trace("Getting summary for module $module before rendering") if $self->trace;
    return $c->digitalocean_agent->ask_p(
      "Please provide a brief summary of the Perl module $module."
    ) if $finished && $websocket && !$summary;
    return Mojo::Promise->resolve($summary);
  })->then(sub ($summary) {
    $c->timers->busy($id => 0);
    return Mojo::Promise->resolve if !$summary;
    $c->log->trace(sprintf "Summary for module $module: %s", substr($summary, 0, 30)) if $self->trace;
    $job->note(summary => $summary);
    $summary = markdown_to_html($summary);
    $c->stash(summary => $summary);
    return Mojo::Promise->resolve($stop);
  });
}

1;