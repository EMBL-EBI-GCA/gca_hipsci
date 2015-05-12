#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;

my $es_host='vg-rs-dev1:9200';
my $cnv_filename;
my $pluritest_filename;

&GetOptions(
    'es_host=s' =>\$es_host,
    'pluritest_file=s' => \$pluritest_filename,
    'cnv_filename=s' => \$cnv_filename,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

my %qc1_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $qc1_details{$split_line[0]}{pluritest}{pluripotency} = $split_line[1];
  $qc1_details{$split_line[0]}{pluritest}{novelty} = $split_line[3];
}
close $pluri_fh;

open my $cnv_fh, '<', $cnv_filename or die "could not open $cnv_filename $!";
<$cnv_fh>;
while (my $line = <$cnv_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $qc1_details{$split_line[0]}{cnv}{num_different_regions} = $split_line[1];
  $qc1_details{$split_line[0]}{cnv}{length_different_regions_Mbp} = $split_line[2];
  $qc1_details{$split_line[0]}{cnv}{length_shared_differences} = $split_line[3];
}
close $cnv_fh;

CELL_LINE:
while (my ($ips_name, $qc1_hash) = each %qc1_details) {
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_name
  );
  next CELL_LINE if !$line_exists;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_name,
    body => {doc => $qc1_details{$ips_name}},
  );
}
