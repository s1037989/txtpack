requires 'perl', '5.036';
requires 'Mojolicious', '9.0';
requires 'IO::Socket::SSL', '2.009';
requires 'Mojo::Pg';
requires 'Minion';
requires 'MCP';
requires 'Markdown::Simple';
requires 'IPC::Run';
requires 'Archive::Tar';
requires 'List::MoreUtils';

on test => sub {
  requires 'Test::More', '0.98';
};