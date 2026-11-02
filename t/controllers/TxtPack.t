use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Mojo::File qw(path);
use Test::Mojo;
use Test::More;
use TxtPack::Test;

my ($t, $minion) = TxtPack::Test->new_app('TxtPack::Application::Web');
my $download_id = $$;
my $download    = path('public')->child("txtpack-$download_id.txt");
$download->spurt('pack result');
END { $download->remove if -f $download }

my $job = TxtPack::Test::Job->new(info_data => {
  args  => ['perl-5.44.0', 'Mojo::UserAgent'],
  notes => {status => ['Installing modules'], installed => ['Mojolicious-9.0']},
  state => 'active',
  task  => 'pack_modules',
});
$minion->jobs->{7} = $job;
$t->app->helper('txtpack.status_p' => sub ($c, $id) {
  $c->stash(info => $job->info, state => 'active', summary => '');
  return Mojo::Promise->resolve;
});

$t->get_ok('/')
  ->status_is(200)
  ->element_exists('form[action="/pack"]');

$t->get_ok('/jobs/7')
  ->status_is(200)
  ->text_like('h1' => qr/txtpack job 7/)
  ->text_like('strong' => qr/active/)
  ->text_like('pre' => qr/Mojo::UserAgent/);

$t->get_ok("/$download_id")
  ->status_is(200)
  ->header_like('Content-Disposition' => qr/txtpack-\Q$download_id\E\.txt/)
  ->content_is('pack result');

done_testing();