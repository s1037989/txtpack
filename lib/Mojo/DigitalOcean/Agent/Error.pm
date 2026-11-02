package Mojo::DigitalOcean::Agent::Error;
use Mojo::Base 'Mojo::Exception', -signatures;

has type        => 'api';
has status      => undef;
has retry_after => undef;

1;

=head1 NAME

Mojo::DigitalOcean::Agent::Error - Structured agent request failure

=head1 DESCRIPTION

A L<Mojo::Exception> with C<type> (C<validation>, C<transport>, C<http>, or
C<api>), optional HTTP C<status>, and optional C<retry_after> header. Stringifies
to a safe local summary; upstream error bodies are deliberately omitted.

=cut
