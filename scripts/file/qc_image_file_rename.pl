#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use File::Find qw(find);
use Data::Dumper;
use File::Basename;
use File::Path qw/make_path/;
use List::Util qw(shuffle);
use File::Copy;

my ($infolder);

GetOptions("infolder=s" => \$infolder);

my @input_files;
find({ wanted => \&findinputfiles}, $infolder);

foreach my $input_file (@input_files){
  my @pathparts = fileparse($input_file);
  my $filename = $pathparts[0];
  ########Edit this section depending on requiements
  #my $dir = $pathparts[1];
  #$dir =~ s/HPSI\d{4}/HPSI/;
  #if (!-d $dir) {
  #  make_path($dir);
  #}
  #$filename =~ s/HPSI\d{4}/HPSI/;
  #my $outfile = $dir.$filename;
  my $outfile = $input_file;
  #$outfile =~ s/HPSI\d{4}/HPSI/;
  $outfile =~ s/qc1hip\d+//;
  print $outfile, "\n";
  move($input_file, $outfile);
  #rmdir($pathparts[1])
  ########Edit this section depending on requiements
}

sub findinputfiles {
  my $F = $File::Find::name;
  if ($F =~ /HPSI\d+/){
    push @input_files, $F;
  } 
  return;
}