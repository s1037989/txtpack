package TxtPack::Application::Web;
use Mojo::Base 'TxtPack', -signatures;

# This method will run once at server start
sub startup {
  my $self = shift->SUPER::startup(@_);

  $self->plugin('Minion::Admin');
  $self->plugin('Perldocs');
  $self->plugin('Status');
  $self->plugin('Timers');

  my $r = $self->app->routes;
  $r->get('/')->to('TxtPack#create')->name('create_txtpack');
  $r->get('/:id')->to('TxtPack#download')->name('download_txtpack');
  $r->get('/jobs/:id')->to('TxtPack#status')->name('status_txtpack');
  $r->websocket('/jobs/:id/ws')->to('TxtPack#status_ws')->name('status_txtpack_ws');
  $r->post('/pack')->to('TxtPack#pack')->name('pack_txtpack');
}

1;
