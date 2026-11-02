package TxtPack::Util;
use Mojo::Base -strict;

use Config;
use Exporter qw(import);
use IPC::Run qw(run);
use Mojo::ByteStream qw(b);
use Mojo::Collection qw(c);
use Mojo::Content::MultiPart;
use Mojo::Content::Single;
use Mojo::File qw(path);
use Mojo::JSON qw(encode_json);
use Mojo::Loader qw(data_section);
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::IOLoop::Subprocess;
use Mojo::Util qw(random_bytes sha1_sum trim xml_escape);
use Time::HiRes qw(time);

our @EXPORT = (qw(
  generate_secret
  perlbrew_path
  cpanm_path
  perlbrew_base_perl
  cpanm_build_log
  run_capture
  run_or_die
  run_quiet
  tail
  parse_cpanm_build_log
  build_multipart
  find_dist_dir
  collect_dist_files
  add_text_file
  multipart_as_text
  multipart_as_script
));

sub generate_secret {
  b(shift->child('.secrets')->tap(sub {
    -s $_ or $_->spurt(c(split //, b(sha1_sum random_bytes 1024)->b64_encode('') =~ s/=+$//r)->shuffle->join(''))
  })->slurp)->split("\n")->reverse->to_array
}

sub perlbrew_path {
  my $root = $ENV{PERLBREW_ROOT};
  return path($root, 'bin', 'perlbrew')->to_string if $root && -x path($root, 'bin', 'perlbrew');
  return 'perlbrew';
}

sub cpanm_path {
  my $root = $ENV{PERLBREW_ROOT};
  return path($root, 'bin', 'cpanm')->to_string if $root && -x path($root, 'bin', 'cpanm');
  return 'cpanm';
}

sub perlbrew_base_perl {
  my $perlbrew = shift;

  my $perl = $ENV{PERLBREW_PERL};
  if (defined $perl && length $perl) {
    $perl =~ s/\@.*\z//;
    return $perl;
  }

  my ($ok, $out) = run_capture([$perlbrew, 'list']);
  if ($ok && $out =~ /^\*\s+(\S+)/m) {
    $perl = $1;
    $perl =~ s/\@.*\z//;
    return $perl;
  }

  return 'perl-' . $Config{version};
}

sub cpanm_build_log {
  my $home = $ENV{PERL_CPANM_HOME};
  unless ($home) {
    die "HOME is not set\n" unless defined $ENV{HOME} && length $ENV{HOME};
    $home = path($ENV{HOME}, '.cpanm')->to_string;
  }
  return path($home, 'build.log');
}

sub run_capture {
  my $cmd = shift;
  my ($out, $err) = ('', '');
  my ($ok, $status) = (0, 0);

  eval {
    $ok     = run $cmd, \undef, \$out, \$err;
    $status = $?;
    1;
  } or do {
    $err .= $@;
    $status = $?;
  };

  return ($ok ? 1 : 0, $out, $err, $status);
}

sub run_or_die {
  my ($cmd, $what) = @_;
  my ($ok, $out, $err) = run_capture($cmd);
  die "$what failed: " . trim($err || $out) . "\n" unless $ok;
}

sub run_quiet {
  my $cmd = shift;
  run_capture($cmd);
}

sub tail {
  my $text = shift // '';
  $text =~ s/\r\n/\n/g;
  return $text if length $text <= 4000;
  return substr($text, -4000);
}

sub parse_cpanm_build_log {
  my $log = shift;
  return ([], undef) unless -f $log;

  my $content = $log->slurp;
  my ($work_dir) = $content =~ /^Work directory is (.+?)\s*$/m;
  $work_dir = trim($work_dir) if defined $work_dir;
  my @installed = $content =~ /^Successfully installed (\S+)/mg;

  return (\@installed, $work_dir);
}

sub build_multipart {
  my ($work_dir, $installed) = @_;
  die "cpanm did not report a work directory\n" unless defined $work_dir && length $work_dir;
  die "cpanm work directory does not exist: $work_dir\n" unless -d $work_dir;

  my $multi = Mojo::Content::MultiPart->new;
  $multi->headers->content_type('multipart/mixed');

  my ($count, @parts, @skipped) = (0);
  for my $dist (@$installed) {
    my $dir = find_dist_dir($work_dir, $dist);
    die "Could not find cpanm work directory for $dist in $work_dir\n" unless $dir;

    for my $item (@{collect_dist_files($dir)}) {
      my ($file, $rel) = @$item;
      my $name = "$dist/$rel";
      push @skipped, $name and next unless add_text_file($multi, $file, $name);
      push @parts, $name;
      $count++;
    }
  }

  die "No text files found for the installed distributions\n" unless $count;
  return ($multi, $count, \@parts, \@skipped);
}

sub find_dist_dir {
  my ($work_dir, $dist) = @_;
  my $dir = path($work_dir, $dist);
  return $dir if -d $dir;

  my ($match) = grep { $_->basename =~ /\A\Q$dist\E(?:[.-]|\z)/ }
    @{path($work_dir)->list({dir => 1})->to_array};
  return $match;
}

sub collect_dist_files {
  my $root = ref $_[0] ? $_[0] : path($_[0]);
  my @files;

  my $walk;
  $walk = sub {
    my ($dir, $prefix) = @_;
    for my $child (@{$dir->list({hidden => 1, dir => 1})->to_array}) {
      next if -l $child;
      my $name = $child->basename;

      if (-d $child) {
        next if $name =~ /\A(?:blib|_build|autom4te\.cache|\.git)\z/;
        $walk->($child, length $prefix ? "$prefix/$name" : $name);
      }
      elsif (-f $child) {
        next if $name =~ /\A(?:Makefile(?:\.old)?|MYMETA\.(?:json|yml)|pm_to_blib|MANIFEST\.bak|Build(?:\.bat)?)\z/;
        push @files, [$child, length $prefix ? "$prefix/$name" : $name];
      }
    }
  };
  $walk->($root, '');

  return \@files;
}

sub add_text_file {
  my ($multi, $file, $name) = @_;
  return 0 unless -f $file && !-l $file;

  my $content = $file->slurp;
  system('iconv', '-f', 'utf-8', '-t', 'utf-8', '-o', '/dev/null', "$file");
  my $text = ($? == -1 || ($? & 127) || $? >> 8) ? 0 : 1;

  $name =~ s/[\r\n]//g;
  $name =~ s/(["\\])/\\$1/g;

  my $part = Mojo::Content::Single->new;
  $part->headers->content_type($text ? 'text/plain' : 'application/octet');
  $part->headers->content_disposition(qq{attachment; filename="$name"});
  $part->asset->add_chunk($text ? $content : '');
  push @{$multi->parts}, $part;

  return 1;
}

sub multipart_as_text {
  my $multi = shift;

  # Make sure the boundary has been added to the Content-Type header
  $multi->build_boundary;

  # Mojo::Content::MultiPart only exposes a chunked body reader
  my ($body, $offset) = ('', 0);
  while (1) {
    my $chunk = $multi->get_body_chunk($offset);
    last unless defined $chunk && length $chunk;
    $body .= $chunk;
    $offset += length $chunk;
  }

  $multi->headers->content_length(length $body);
  return $multi->headers->to_string . "\r\n\r\n" . $body;
}

sub multipart_as_script {
  sprintf "%s\n\n__DATA__\n%s\n",
    data_section(__PACKAGE__, 'self_extracting_multipart.pl'),
    multipart_as_text(shift);
}

1;

__DATA__

@@ self_extracting_multipart.pl
#!/usr/bin/env perl
use Mojo::Base -strict, -signatures;

use Archive::Tar;
use List::MoreUtils qw(firstidx);
use Mojo::Collection qw(c);
use Mojo::Content::MultiPart;
use Mojo::Content::Single;
use Mojo::File qw(curfile path tempdir);

BEGIN {
  $ENV{HTTP_PROXY}  = $ENV{http_proxy}  = 'http://localhost';
  $ENV{HTTPS_PROXY} = $ENV{https_proxy} = 'https://localhost';
}

my $multi = Mojo::Content::MultiPart->new;
$multi->parse(do { binmode DATA, ':raw'; local $/; <DATA> });

my ($order, $dir);
my $tempdir;
Mojo::Collection->new(@{$multi->parts})->map(sub ($part) {
  my $disposition = $part->headers->content_disposition // '';
  my ($name) = $disposition =~ /filename="((?:\\.|[^"])*)"/;
  $name = defined $name && length $name ? $name : 'file';
  $name =~ s/\\(.)/$1/g;
  $name =~ s/[\x00-\x1f]//g;
  $name = path($name);
  my $package = $name->[0];
  $_ = [$package, $name, $part];
})->tap(sub {
  $order = $_->map(sub{$_->[0]})->uniq->to_array
})->reduce(sub {
  my $idx = firstidx { $_ eq $b->[0] } @$order;
  $a->[$idx] ||= c;
  push @{$a->[$idx]}, [$b->[1], $b->[2]];
  return $a;
}, c)->each(sub ($e, $i) {
  my $tar = Archive::Tar->new;
  $_->each(sub { $tar->add_data($_->[0], $_->[1]->asset->slurp) })->tap(sub { printf "Added %d files\n", $_->size });
  my $tarball = curfile->sibling(curfile->basename('.txt'))->child($order->[$i-1].'.tar.gz');
  return if grep { /-n/ } @ARGV;
  $tar->write($tarball->tap(sub { $_->dirname->make_path }), COMPRESS_GZIP);
  printf "Wrote %s\n", $tarball;
  return unless grep { /-i/ } @ARGV;
  $tempdir = tempdir(CLEANUP => 0);
  system('cpanm', '-nv', "$tarball");
  exit if $? == -1 || ($? & 127) || $? >> 8;
});
printf "Installed to $tempdir\n" if $tempdir;
