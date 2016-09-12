#!/usr/bin/env perl

#Example: perl import_new_bams.pl -bamfilelists /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/ENA.ERP007111.rnaseq.healthy_volunteers.analysis_files.tsv -bamlocaldir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbams

use strict;
use warnings;

use Getopt::Long;

my ($bamlocaldir, @bamfilelists);

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "bamfilelists=s" => \@bamfilelists,
);

die "Missing local directory to store BAMS in -bamlocaldir" if !$bamlocaldir;
die "Missing file release tables (*.rnaseq.healthy_volunteers.analysis_files.tsv) -bamfilelists"|| !@bamfilelists;

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