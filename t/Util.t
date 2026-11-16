use Mojo::Base -strict;

use Archive::Tar;
use Mojo::Content::MultiPart;
use Mojo::Content::Single;
use Mojo::File qw(path tempdir);
use Test::Mojo;
use Test::More;
use TxtPack::Util qw(
  add_text_file build_multipart perlbrew_base_perl perlbrew_path cpanm_path cpanm_build_log
  collect_dist_files find_dist_dir generate_secret multipart_as_script multipart_as_text parse_cpanm_build_log
  run_capture run_or_die run_quiet tail
);

my $t   = Test::Mojo->new;
my $dir = tempdir;

my $secret = generate_secret($dir);
$t->test('ok', @$secret && length $secret->[0] >= 40, 'creates a local application secret');
$t->test('is_deeply', generate_secret($dir), $secret, 'reuses the existing secret');

my $perlbrew_dir = $dir->child('bin')->make_path;
my $perlbrew     = $perlbrew_dir->child('perlbrew')->spurt('');
chmod 0755, "$perlbrew";
my $cpanm = $perlbrew_dir->child('cpanm')->spurt('');
chmod 0755, "$cpanm";
local $ENV{PERLBREW_ROOT} = $dir->to_string;
$t->test('is', perlbrew_path(), $perlbrew->to_string, 'finds executable perlbrew under PERLBREW_ROOT');
$t->test('is', cpanm_path(), $cpanm->to_string, 'finds executable cpanm under PERLBREW_ROOT');

local $ENV{PERLBREW_PERL} = 'perl-5.44.0@default';
$t->test('is', perlbrew_base_perl('perlbrew'), 'perl-5.44.0', 'removes the perlbrew lib suffix');
local $ENV{PERL_CPANM_HOME} = $dir->to_string;
$t->test('is', cpanm_build_log()->to_string, $dir->child('build.log')->to_string, 'locates the cpanm build log');

my ($ok, $out, $err) = run_capture([$^X, '-e', 'print "stdout"; warn "stderr"']);
$t->test('is', $ok, 1, 'captures a successful command');
$t->test('is', $out, 'stdout', 'captures standard output');
$t->test('like', $err, qr/stderr/, 'captures standard error');

my $run_error = '';
eval { run_or_die([$^X, '-e', 'exit 0'], 'successful command') };
$run_error = $@;
$t->test('is', $run_error, '', 'does not throw for a successful command');
my ($quiet_ok) = run_quiet([$^X, '-e', 'exit 0']);
$t->test('is', $quiet_ok, 1, 'runs a command quietly');

$t->test('is', tail('x' x 4001), 'x' x 4000, 'keeps only the final 4000 characters');
$t->test('is', tail("first\r\nlast\r\n"), "first\nlast\n", 'normalizes line endings');

my $build_dir = $dir->child('work')->make_path;
my $fetch     = 'Mojo-Base-1.0.tar.gz';
my $dist      = 'Mojo-Base-1.0';
my $dist_dir  = $build_dir->child($dist)->make_path;
$dist_dir->child('README')->spurt("module docs\n");
$dist_dir->child('Makefile')->spurt("generated\n");
my $log = $dir->child('build.log');
$log->spurt("Work directory is $build_dir\nFetching file://$build_dir/$fetch\nSuccessfully installed $dist\n");
my ($fetching, $installed, $work_dir) = parse_cpanm_build_log($log);
$t->test('is_deeply', $fetching, [$fetch], 'parses fetched distributions');
$t->test('is_deeply', $installed, [$dist], 'parses installed distributions');
$t->test('is', $work_dir, "$build_dir", 'parses the cpanm work directory');
$t->test('is', "" . find_dist_dir($build_dir, $dist), "$dist_dir", 'finds the distribution directory');
my $files = collect_dist_files($dist_dir);
$t->test('is_deeply', [sort map { $_->[1] } @$files], ['Makefile', 'README'], 'includes generated build files');

# build_multipart removes subdirs and extracts non-build.log files from work_dir.
$dist_dir->remove_tree;
{
  my $src = tempdir;
  my $sdir = $src->child($dist)->make_path;
  $sdir->child('README')->spurt("module docs\n");
  $sdir->child('Makefile')->spurt("generated\n");
  my $cwd = path->to_string;
  chdir $src->to_string;
  my $tar = Archive::Tar->new;
  $tar->add_files($dist, "$dist/README", "$dist/Makefile");
  $tar->write($build_dir->child($fetch)->to_string, COMPRESS_GZIP);
  chdir $cwd;
}

my ($multi, $count, $parts, $skipped) = build_multipart($build_dir, $fetching, $installed);
$t->test('is', $count, 2, 'adds installable text files to the multipart document');
$t->test('is_deeply', [sort @$parts], ["$dist/Makefile", "$dist/README"], 'records included file names');
$t->test('is_deeply', $skipped, [], 'reports no skipped files');
my $text = multipart_as_text($multi);
$t->test('like', $text, qr/\Q$dist\E\/README/, 'serializes multipart content');
$t->test('like', multipart_as_script($multi), qr/__DATA__\n/, 'embeds multipart content in a self-extracting script');

my $single = Mojo::Content::Single->new;
$single->asset->add_chunk('body');
my $multipart = Mojo::Content::MultiPart->new(parts => [$single]);
$t->test('ok', add_text_file($multipart, $build_dir->child("$dist/README"), 'README'), 'adds a text file as a multipart part');

done_testing();
