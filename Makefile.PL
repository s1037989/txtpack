use strict;
use warnings;
use ExtUtils::MakeMaker;

package MY;

sub test {
  my $self = shift;
  my $make = $self->SUPER::test(@_);
  my $prove = 'prove -l ' . join ' ', map { "t/$_/*.t" } qw(applications base controllers plugins tasks);
  $make =~ s/^(test :: \$\(TEST_TYPE\)\n)/$1\t$prove\n/m;
  return $make;
}

package main;

WriteMakefile(
  NAME             => 'TxtPack',
  VERSION_FROM     => 'lib/TxtPack.pm',
  ABSTRACT         => 'Mojolicious application for packaging Perl modules',
  AUTHOR           => 'TxtPack contributors',
  LICENSE          => 'perl_5',
  MIN_PERL_VERSION => '5.036',
  EXE_FILES        => [qw(script/txtpack-web script/txtpack-worker)],
  PREREQ_PM        => {
    'Mojolicious'      => '9.0',
    'IO::Socket::SSL'  => '2.009',
    'Mojo::Pg'         => 0,
    'Minion'           => 0,
    'MCP'              => 0,
    'Markdown::Simple' => 0,
    'IPC::Run'         => 0,
    'Archive::Tar'     => 0,
    'List::MoreUtils'  => 0,
  },
  TEST_REQUIRES => {
    'Test::More' => '0.98',
  },
);