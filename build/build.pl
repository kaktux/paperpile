#!/usr/bin/perl -w

use strict;
use Module::ScanDeps;
use Data::Dumper;
use File::Path;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Copy::Recursive qw(fcopy dircopy);

my $platform   = 'linux64';
my $cat_dir    = '../catalyst';
my $target_dir = '/home/wash/tmp/dist/';

my @ignore = ( qr([~#]),
               qr{/tmp/},
               qr{/t/},
               qr{\.gitignore},
               qr{/perl5/$platform/(cpan|base)}
             );

my @add = ("perl5/$platform/base/unicore");

my $cpan = catfile( $target_dir,'catalyst', 'perl5', $platform, 'cpan' );
mkpath($cpan);

my $modules = scan_deps(
  files   => ['testrun.pl'],
  execute => 1,
);

foreach my $m ( sort { $a->{key} cmp $b->{key} } values %$modules ) {

  my $relative = $m->{key};

  # relative path is not correct for some autoloads, adjust manually
  $relative = $1 if $relative =~ /\/.*\/(auto\/.*)$/;

  next if $relative =~ /Paperpile/;

  print $m->{type}, ": ", $relative, "\n";

  fcopy( $m->{file}, catfile( $cpan, $relative ) ) or die($!);
}


my @list = @add;

find( {
    no_chdir => 1,
    wanted   => sub {
      my $name = $File::Find::name;
      return if -d $name;
      foreach my $r (@ignore) {
        return if $name =~ $r;
      }
      push @list, File::Spec->abs2rel( $name, $cat_dir );
      }
  },
  $cat_dir
);

foreach my $file (@list) {

  if (-d  catfile( $cat_dir, $file)){
    dircopy( catfile( $cat_dir, $file ), catfile( $target_dir, 'catalyst', $file ) ) or die( $!, $file );
    next;
  }

  my ( $volume, $dir, $base ) = File::Spec->splitpath($file);
  $dir = catfile( $target_dir, 'catalyst', $dir );
  mkpath($dir) if !-d $dir;
  fcopy( catfile( $cat_dir, $file ), catfile( $target_dir, 'catalyst', $file ) ) or die( $!, $file );
}

