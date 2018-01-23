#!/usr/bin/env perl

use strict;
use warnings;

my $beagle_phased_file = '/nfs/research1/hipsci/drop/hip-drop/tracked/gtarray/hla_typing/20150526_235_OA_samples/hipsci.wec.gtarray.HumanCoreExome-12_v1_0.235_OA_samples.20150526.genotypes.chr6_IMPUTED.bgl.phased';
#my $beagle_phased_file = '/nfs/research1/hipsci/controlled/gtarray/hla_typing/20150526_623_MA_samples/hipsci.wec.gtarray.HumanCoreExome-12_v1_0.623_MA_samples.20150526.genotypes.chr6_IMPUTED.bgl.phased';

open my $IN, '<', $beagle_phased_file or die "could not open $beagle_phased_file $!";
my @sample_names;
my $line = <$IN>;
chomp $line;
my @split_line = split(' ', $line);
shift @split_line;
shift @split_line;
while (scalar @split_line) {
  push(@sample_names, shift @split_line);
  shift @split_line;
}

<$IN>;
<$IN>;

my %matches;
my %mismatches;
while (my $line = <$IN>) {
  chomp $line;
  @split_line = split(' ', $line);
  foreach my $i (0..$#sample_names) {
    if ($split_line[$i*2 +2] eq $split_line[$i*2 +3]) {
      $matches{$sample_names[$i]} += 1;
    }
    else {
      $mismatches{$sample_names[$i]} += 1;
    }
  }
}

close $IN;

foreach my $sample (sort {$mismatches{$a} <=> $mismatches{$b} || $a cmp $b } @sample_names) {
  print join("\t", $sample, $matches{$sample}, $mismatches{$sample}), "\n";
}
