package TxtPack::Application::Core;
use Mojo::Base 'TxtPack', -signatures;

# This method will run once at server start
sub startup {
  my $self = shift->SUPER::startup(@_);
  
  # my $minion = $self->app->minion;
}

1;
