package TxtPack::Controller::TxtPack;
use Mojo::Base 'TxtPack::Controller', -signatures;

use Mojo::Util qw(trim);

sub create { shift->render }

sub download ($self) {
  my $filename = sprintf 'txtpack-%d.txt', $self->param('id');
  $self->res->headers->content_type('text/plain');
  $self->res->headers->content_disposition("attachment; filename=$filename;");
  $self->reply->static($filename);
}

sub pack ($self) {
  my @modules = grep { length } map { trim($_) } split /\r?\n/, $self->param('modules') // '';
  return $self->render(text => "Please provide at least one module.\n", status => 400) unless @modules;

  for my $module (@modules) {
    return $self->render(text => qq{Invalid module name "$module".\n}, status => 400)
      if $module =~ /\A-/;
  }

  my $id = $self->minion->enqueue(pack_modules => ['perl-5.44.0', @modules]);
  $self->log->info("pack_modules $id");
  $self->redirect_to("/jobs/$id");
}

sub status ($self) {
  $self->render_later;
  $self->stash(layout => 'default');
  $self->txtpack->status_p($self->param('id'))->then(sub {
    $self->render;
  })->catch(sub ($err) {
    $self->render(error => "Error: $err");
  });
}

sub status_ws ($self) {
  my $id = $self->param('id');
  my $stop = sub { $self->timers->stop };
  my $timer = Mojo::IOLoop->recurring(1 => sub {
    $self->txtpack->status_p($id, $stop)->then(sub ($stop=undef) {
      $self->send({text => $self->render_to_string(template => 'txt_pack/status')} => $stop || ());
      $self->log->trace(sprintf "Sent %swebsocket update for job $id", $stop ? 'final ' : '');
    });
  });
  $self->timers->add($id => $timer);
  $self->on(finish => $stop);
}

1;
