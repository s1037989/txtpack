package Mojolicious::Plugin::DigitalOceanAgent;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojo::DigitalOcean::Agent;

our $VERSION = '0.01';

sub register ($self, $app, $options) {
    my %config = (%{$app->config->{digitalocean_agent} // {}}, %{$options // {}});
    my $helper = delete($config{helper}) // 'digitalocean_agent';
    die "Invalid DigitalOceanAgent helper name\n" unless $helper =~ /\A[a-zA-Z_]\w*\z/;
    $config{endpoint} //= $ENV{DO_AGENT_URL};
    $config{api_key}  //= $ENV{DO_AGENT_KEY};

    my $client = Mojo::DigitalOcean::Agent->new(%config);
    $app->helper($helper => sub ($c) { return $client });
    return $client;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::DigitalOceanAgent - Use a deployed DigitalOcean AI agent

=head1 SYNOPSIS

    plugin DigitalOceanAgent => {
        endpoint => $ENV{DO_AGENT_URL},
        api_key  => $ENV{DO_AGENT_KEY},
    };

    post '/ask' => sub ($c) {
        $c->render_later;
        $c->digitalocean_agent->ask_p($c->param('question'))->then(sub ($answer) {
            $c->render(json => {answer => $answer});
        })->catch(sub ($error) {
            $c->log->error("$error");
            $c->render(status => 502, json => {error => 'Agent request failed'});
        });
    };

=head1 DESCRIPTION

Registers a reusable non-blocking L<Mojo::DigitalOcean::Agent> client. Options
override C<< app->config->{digitalocean_agent} >>. Missing endpoint/key values
fall back to C<DO_AGENT_URL> and C<DO_AGENT_KEY>. C<helper> changes the helper
name. All remaining options go to the client. See the distribution README for
configuration, response contracts, installation, and examples.

=cut
