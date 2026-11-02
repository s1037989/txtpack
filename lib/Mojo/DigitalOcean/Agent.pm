package Mojo::DigitalOcean::Agent;
use Mojo::Base -base, -signatures;

use Mojo::Cache;
use Mojo::DigitalOcean::Agent::Error;
use Mojo::JSON qw(decode_json encode_json false);
use Mojo::Promise;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Util qw(decode encode);

has [qw(_url _api_key _ua _defaults)];
has cache => sub { Mojo::Cache->new(max_keys => 100) };

sub new ($class, %config) {
    my $self = $class->SUPER::new;
    my %known = map { $_ => 1 } qw(endpoint api_key defaults ua allow_http
        connect_timeout inactivity_timeout request_timeout ca);
    die "Unknown DigitalOceanAgent configuration option\n"
        if grep { !$known{$_} } keys %config;

    my $endpoint = $config{endpoint};
    die "DigitalOceanAgent endpoint is required\n"
        unless defined($endpoint) && !ref($endpoint) && length($endpoint);
    my $url = Mojo::URL->new($endpoint);
    die "DigitalOceanAgent requires an absolute HTTPS endpoint\n"
        unless $url->is_abs && $url->host
        && ($url->scheme eq 'https' || ($config{allow_http} && $url->scheme eq 'http'));
    die "DigitalOceanAgent endpoint must not contain user info or a fragment\n"
        if defined($url->userinfo) || defined($url->fragment);

    my $path = $url->path->to_string;
    $path =~ s{/+\z}{};
    my %paths = (
        ''                         => '/api/v1/chat/completions',
        '/api'                     => '/api/v1/chat/completions',
        '/api/v1'                  => '/api/v1/chat/completions',
        '/api/v1/chat/completions'  => '/api/v1/chat/completions',
        '/v1/chat/completions'      => '/v1/chat/completions',
    );
    die "Use an agent root URL, /api, /api/v1, or full chat completions URL\n"
        unless exists $paths{$path};
    $url->path($paths{$path});
    $url->query->param(agent => 'true');

    my $api_key = $config{api_key};
    die "DigitalOceanAgent api_key is required and must be a non-whitespace ASCII token\n"
        unless defined($api_key) && !ref($api_key) && $api_key =~ /\A[\x21-\x7e]+\z/;
    my $defaults = $config{defaults} // {};
    die "DigitalOceanAgent defaults must be a hash reference\n" unless ref($defaults) eq 'HASH';
    die "DigitalOceanAgent defaults cannot contain messages or enable streaming\n"
        if exists($defaults->{messages}) || $defaults->{stream};
    my $snapshot = eval { decode_json(encode_json($defaults)) };
    die "DigitalOceanAgent defaults must be JSON serializable\n" if $@;

    my $ua = $config{ua} // Mojo::UserAgent->new;
    die "DigitalOceanAgent ua must be a Mojo::UserAgent\n"
        unless eval { $ua->isa('Mojo::UserAgent') };
    for my $setting (qw(connect_timeout inactivity_timeout request_timeout)) {
        my $value = $config{$setting} // ($setting eq 'connect_timeout' ? 10 : 120);
        die "DigitalOceanAgent timeouts must be positive numbers\n"
            unless !ref($value) && $value =~ /\A(?:\d+(?:\.\d*)?|\.\d+)\z/ && $value > 0;
        $ua->$setting($value);
    }
    # Never forward the bearer key to a redirect target or disable TLS verification.
    $ua->max_redirects(0)->insecure(0);
    $ua->ca($config{ca}) if defined $config{ca};
    return $self->_url($url)->_api_key($api_key)->_ua($ua)->_defaults($snapshot);
}

sub endpoint ($self) { return $self->_url->clone }

sub chat_p ($self, $request) {
    # Validation and encoding errors reject the returned promise, just like I/O errors.
    return Mojo::Promise->resolve->then(sub {
        my $payload = $self->_payload($request);
        my $tx = $self->_ua->build_tx(POST => $self->_url->clone => {
            Authorization => 'Bearer ' . $self->_api_key,
            Accept        => 'application/json',
        } => json => $payload);

        return $self->_ua->start_p($tx)->catch(sub ($error) {
            die _error('transport', 'Agent transport failed (connection, TLS, or timeout)');
        })->then(sub ($tx) {
            my $response = $tx->res;
            unless ($response->is_success) {
                my $status = $response->code;
                die _error('http', 'Agent returned HTTP ' . ($status // 'unknown'),
                    status => $status, retry_after => $response->headers->header('Retry-After'));
            }
            my $data = eval { decode_json($response->body) };
            die _error('api', 'Agent returned invalid JSON', status => $response->code)
                if $@ || ref($data) ne 'HASH';
            die _error('api', 'Agent returned an error payload', status => $response->code)
                if exists $data->{error};
            die _error('api', 'Agent response has no valid completion choices', status => $response->code)
                unless ref($data->{choices}) eq 'ARRAY' && @{$data->{choices}}
                && !grep { ref($_) ne 'HASH' || ref($_->{message}) ne 'HASH' } @{$data->{choices}};
            return $data;
        });
    });
}

sub ask_p ($self, $prompt, $options = {}) {
    my $content = $self->cache->get($prompt);
    return Mojo::Promise->resolve($content) if $content;
    return Mojo::Promise->resolve->then(sub {
        die _error('validation', 'Prompt must be a non-empty string')
            unless defined($prompt) && !ref($prompt) && $prompt =~ /\S/;
        die _error('validation', 'Ask options must be a hash reference') unless ref($options) eq 'HASH';
        my %request = %$options;
        die _error('validation', 'Use history with ask_p, or messages with chat_p')
            if exists $request{messages};
        my $history = delete($request{history}) // [];
        die _error('validation', 'History must be an array reference') unless ref($history) eq 'ARRAY';
        $request{messages} = [@$history, {role => 'user', content => $prompt}];
        return $self->chat_p(\%request);
    })->then(sub ($data) {
        my $content = encode 'UTF-8', $data->{choices}[0]{message}{content};
        die _error('api', 'Completion has no text content; use chat_p for tool calls or refusals')
            unless defined($content) && !ref($content);
        $self->cache->set($prompt => $content);
        return $content;
    });
}

sub _payload ($self, $request) {
    die _error('validation', 'Chat request must be a hash reference') unless ref($request) eq 'HASH';
    my %payload = (model => 'ignored', %{$self->_defaults}, %$request);
    die _error('validation', 'Streaming is not supported by chat_p or ask_p') if $payload{stream};
    my $messages = $payload{messages};
    die _error('validation', 'Messages must be a non-empty array reference')
        unless ref($messages) eq 'ARRAY' && @$messages;
    for my $message (@$messages) {
        die _error('validation', 'Each message must have a role')
            unless ref($message) eq 'HASH' && defined($message->{role})
            && !ref($message->{role}) && length($message->{role});
        my $content = $message->{content};
        die _error('validation', 'Message content must be text, a content-parts array, or null')
            if defined($content) && ref($content) && ref($content) ne 'ARRAY';
    }
    $payload{stream} = false;
    my $snapshot = eval { decode_json(encode_json(\%payload)) };
    die _error('validation', 'Chat request must be JSON serializable') if $@;
    return $snapshot;
}

sub _error ($type, $message, %fields) {
    my $error = Mojo::DigitalOcean::Agent::Error->new($message)->type($type);
    $error->$_($fields{$_}) for keys %fields;
    return $error;
}

1;

=head1 NAME

Mojo::DigitalOcean::Agent - Promise-based DigitalOcean agent inference client

=head1 METHODS

=head2 chat_p

    $client->chat_p({messages => [{role => 'user', content => 'Hello'}]});

Resolves to the full decoded completion hash reference, retaining metadata.
Per-call parameters override C<defaults>. C<stream> is always false.

=head2 ask_p

    $client->ask_p('Next question', {history => \@messages, max_tokens => 512});

Resolves to the first choice's text. History is optional and never persisted or
modified. Use C<chat_p> to access tool calls, refusals, or non-text completions.

=head2 endpoint

Returns a copy of the normalized request URL.

=head1 ERRORS

Configuration mistakes throw during construction/registration. Request validation,
transport, HTTP, and response errors reject with
L<Mojo::DigitalOcean::Agent::Error>. No automatic retries are made.

=cut
