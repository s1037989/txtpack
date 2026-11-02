package TxtPack::Plugin::Perldocs;
use Mojo::Base 'TxtPack::Plugin', -signatures;

use MCP::Server;

has mcp => sub ($self) { MCP::Server->new(name => $self->name, log => $self->log) };

sub register {
  my ($self, $app, $conf) = shift->SUPER::register(@_);

  $self->load_tools->on(tools => sub ($mcp, $tools, $context) {
    $app->log->debug("Loaded tools: " . join(', ', map { $_->name } @$tools));
  });

  $app->routes->any('/mcp' => $self->mcp->to_action);
}

sub load_tools ($self) {
  $self->mcp->tool(
    name         => 'perldocs',
    description  => 'Look up the documentation of a Perl module',
    input_schema => {
      type       => 'object',
      properties => {module => {type => 'string', description => 'Module name, such as Mojo::UserAgent'}},
      required   => ['module']
    },
    code => sub ($tool, $args) {
      my $module = $args->{module};
      return $tool->text_result("Not a module name: $module", 1) unless $module =~ /^\w+(?:::\w+)*\z/;
      open my $doc, '-|', 'perldoc', '-o', 'text', '-T', $module or return $tool->text_result('Found no perldoc', 1);
      my $text = do { local $/; <$doc> };
      return length($text // '') ? $text : $tool->text_result("Found no documentation for $module", 1);
    }
  );
  return $self->mcp;
}

1;