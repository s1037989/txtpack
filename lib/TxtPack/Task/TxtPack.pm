package TxtPack::Task::TxtPack;
use Mojo::Base 'Minion::Job', -signatures;

use Mojo::Util qw(decode);
use TxtPack::Util;

sub run ($self, $perl, @modules) {
  my $guard = $self->minion->guard('txtpack-cpanm', 86_400);
  return $self->retry({delay => 30}) unless $guard;
  $self->note(perl => $perl);
  $self->note(modules => \@modules);

  my $app    = $self->app;
  my $lib    = 'txtpack-job-' . $self->id;
  my $start  = time;
  my $target = "$perl\@$lib";

  $self->note(status => ["Creating temporary perlbrew lib $target"]);
  run_or_die(['perlbrew', 'lib', 'create', $target], 'perlbrew lib create');

  my $build_log = cpanm_build_log();
  unlink "$build_log" if -e "$build_log";

  my $progress = Mojo::IOLoop->recurring(15 => sub {
    $self->note(progress => sprintf 'running for %d seconds...', time - $start);
  });

  my $pid = $self->pid;
  local $SIG{USR1} = sub { kill 'USR1', $pid if $pid };
  local $SIG{USR2} = sub { kill 'USR2', $pid if $pid };

  my $subprocess = Mojo::IOLoop::Subprocess->new;
  $subprocess->on(progress => sub ($subprocess, $data) {
    $self->note(_pid => $data->{pid}) if $data->{pid};
  });

  $self->note(status => [$self->info->{notes}{status}->@*, sprintf 'Installing %d modules with cpanm', scalar @modules]);
  $self->app->log->info(sprintf 'in process %s %s', $$, $pid);
  $subprocess->run_p(sub ($subprocess) {
    $self->app->log->info(sprintf 'in subprocess %s', $$);
    my $fh;
    my $cmd = sprintf "perlbrew exec --with $target cpanm --notest --self-contained";
    $self->note(status => [$self->info->{notes}{status}->@*, "$cmd ..."]);
    my $pid = open($fh, '-|', join ' ', $cmd, @modules); # BUG: how to get the exit code of the open call to return fail to minion??
    $subprocess->progress({pid => $pid});

    my $stream = Mojo::IOLoop::Stream->new($fh)->timeout(0);
    my $stream_id = Mojo::IOLoop->stream($stream);
    $stream->on(read => sub ($stream, $chunk) {
      warn sprintf "read %d bytes\n", length($chunk);
      $self->note(status => [$self->info->{notes}{status}->@*, split /\n/, decode 'UTF-8', $chunk]);
    });
    $stream->on(error => sub { warn 'error'; Mojo::IOLoop->remove($stream_id) });
    $stream->on(close => sub {
      $self->app->log->info("close stream $stream");
      $self->note(_pid => undef);
      Mojo::IOLoop->remove($stream);
      Mojo::IOLoop->stop;
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  })->timeout(86_400 => 'timeout')->then(sub {
    my ($installed, $work_dir) = parse_cpanm_build_log($build_log);
    $self->note(status => [$self->info->{notes}{status}->@*, 'Build log ' . $build_log . ' file=' . (-f $build_log ? 1 : 0)
        . ' size=' . (-s $build_log // 0) . ' installed=' . scalar(@$installed)]);
    $self->note(installed => $installed);
    $self->note(work_dir => $work_dir);
    return ($installed, $work_dir);
  })->then(sub ($installed, $work_dir) {
    $self->note(status => [$self->info->{notes}{status}->@*, 'Found ' . scalar(@$installed) . ' installed distribution(s)']);
    return build_multipart($work_dir, $installed);
  })->then(sub ($multi, $count, $parts, $skipped) {
    my $public = $app->home->child('public');
    $public->make_path unless -d "$public";
    my $output = $public->child("txtpack-$self->{id}.txt");
    $self->note(status => [$self->info->{notes}{status}->@*, "generating $output"]);
    $output->spurt(multipart_as_script($multi));
    $self->note(txtpack => $output->to_string);
  })->then(sub {
    $self->note(status => [$self->info->{notes}{status}->@*, "download ready at /txtpack-$self->{id}"]);
    $self->finish({download_url => "/txtpack-$self->{id}"});
  })->catch(sub ($err) {
    $self->fail($err);
    $self->note(status => [$self->info->{notes}{status}->@*, "Error!  $err"]);
    $self->note(progress => sprintf 'task failed after %d seconds...', time - $start);
  })->finally(sub {
    $self->note(progress => undef);
    $self->note(status => [$self->info->{notes}{status}->@*, "Cleaning up"]);
    run_quiet(['perlbrew', 'lib', 'delete', $target]);
  })->wait;

  if (my $exit = $subprocess->exit_code) {
    $self->app->log->error("job fail $exit");
  }

  Mojo::IOLoop->remove($progress);
}

1;