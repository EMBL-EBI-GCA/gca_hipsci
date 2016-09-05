#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
#use File::Remote qw(:replace);

my ($bamlocaldir, @bamfilelists);

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "bamfilelists=s" => \@bamfilelists,
);

die "Missing parameters" if !$bamlocaldir || !@bamfilelists ;

chdir $bamlocaldir;

#TODO could make this smarter to check for exisiting files that need updating using md5s

foreach my $table (@bamfilelists){
  open my $fh, '<', $table or die "could not open $table: $!";
  while (my $line = <$fh>) {
    if ($line =~/^ftp/){
      my @parts = split(/\t/, $line);
      my $ftpfile = $parts[0];
      if ($ftpfile =~ /\.bam$/){
        system "wget $ftpfile";
        system "wget $ftpfile.bai";
      }
    }
  }
  close($fh);
}