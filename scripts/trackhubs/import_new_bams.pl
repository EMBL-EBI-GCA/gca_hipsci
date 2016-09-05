#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;

my ($bamlocaldir, @bamfilelists);

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "bamfilelists=s" => \@bamfilelists,
);

die "Missing parameters" if !$bamlocaldir || !@bamfilelists ;

chdir $bamlocaldir;

my $counter = 0;

foreach my $table (@bamfilelists){
  open my $fh, '<', $table or die "could not open $table: $!";
  while (my $line = <$fh>) {
    if ($line =~/^ftp/){
      my @parts = split(/\t/, $line);
      my $ftpfile = $parts[0];
      if ($ftpfile =~ /\.bam$/){
        system "wget -N $ftpfile";
        system "wget -N $ftpfile.bai";
        $counter = $counter+2;
      }
    }
  }
  close($fh);
}

print "\nExpecting $counter files\n";