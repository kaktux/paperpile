#!/usr/bin/perl

# Wrapper script to ensure the t/run.pl is calles with the right perl executable

use Config;

my $platform='';
my $arch_string=$Config{archname};

if ( $arch_string =~ /linux/i ) {
  $platform = ($arch_string =~ /64/) ? 'linux64' : 'linux32';
}

if ( $arch_string =~ /(darwin|osx)/i ) {
  $platform = 'osx';
}

$ENV{PERL5LIB}=undef;
$ENV{BUILD_PLATFORM}=$platform;

exec("../perl5/$platform/bin/paperperl t/run.pl" . join(" ",@ARGV));
