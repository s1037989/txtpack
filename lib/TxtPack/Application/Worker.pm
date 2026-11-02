package TxtPack::Application::Worker;
use Mojo::Base 'TxtPack', -signatures;

# This method will run once at server start
sub startup {
  my $self = shift->SUPER::startup(@_);
  
  my $minion = $self->app->minion;
  $minion->add_task(pack_modules => 'TxtPack::Task::TxtPack');
}

1;
