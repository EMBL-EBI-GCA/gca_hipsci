#!/usr/bin/env perl

#Example: perl import_new_bams.pl -bamfilelists /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/hipsci_files.tsv -bamlocaldir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbams

use strict;
use warnings;

use Getopt::Long;

my ($bamlocaldir, @bamfilelists);

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "bamfilelists=s" => \@bamfilelists,
);

die "Missing local directory to store BAMS in -bamlocaldir" if !$bamlocaldir;
die "Missing hipsci file list (hipsci_files.tsv from export from http://www.hipsci.org/lines/#/files?File%20format%5B%5D=bam) -bamfilelists" if !@bamfilelists;

chdir $bamlocaldir;

my $counter = 0;

foreach my $table (@bamfilelists){
  open my $fh, '<', $table or die "could not open $table: $!";
  while (my $line = <$fh>) {
    if ($line =~/^HPSI/){
      my @parts = split(/\t/, $line);
      if ($parts[2] =~/^ftp/){
        my $ftpfile = $parts[2].$parts[0];
        if ($ftpfile =~ /\.bam$/){
          system "wget -N $ftpfile";
          system "wget -N $ftpfile.bai";
          $counter = $counter+2;
        }
      }
    }
  }
  close($fh);
}

print "\nExpecting $counter files\n";