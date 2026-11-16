package Mojo::Log::Role::Context;
use Mojo::Base -role;
use overload '""' => sub { shift->to_string }, fallback => 1;

use Mojo::Collection qw(c);
use Mojo::Util qw(trim);
use Text::ParseWords;

sub context {
  my ($self, @context) = @_;
  @context = map { Mojo::Log::Context->new($_) } map { !ref ? map { trim $_ } grep { $_ } parse_line('"', 0, s/[\[\]]/"/gr) : $_ } @context;
  unshift @context, @{$self->{context}||=c};
  return $self->new(parent => $self->{parent} || $self, context => \@context, level => $self->level);
}

sub to_string { shift->history->[-1] }

package Mojo::Log::Context;
use Mojo::Base -base;
use overload '""' => sub { '[' . shift->value . ']' }, fallback => 1;

has key   => 'undef';
has value => undef;

sub key_value { join '=', $_[0]->key, $_[0]->value }

sub new {
  my $self = shift->SUPER::new;
  if (ref $_[0] eq 'ARRAY') {
    my @array = @{$_[0]};
    $self->key($array[0])->value($array[1]);
  }
  elsif (ref $_[0] eq 'HASH') {
    my @hash = %{$_[0]};
    $self->key($hash[0])->value($hash[1]);
  }
  elsif (ref $_[0] && $_[0]->isa(__PACKAGE__)) {
    $self = $_[0];
  }
  elsif (!ref $_[0]) {
    my ($k, $v);
    if ($_[0] =~ /=/) {
      ($k, $v) = split /=/, $_[0], 2;
      $self->key($k)->value($v);
    }
    else {
      $self->value($_[0]);
    }
  }
  return $self;
}

1;