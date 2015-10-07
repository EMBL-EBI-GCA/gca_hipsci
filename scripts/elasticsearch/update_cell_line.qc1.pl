#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $cnv_filename;
my $pluritest_filename;
my $allowed_samples_gtarray_file;
my $allowed_samples_gexarray_file;

&GetOptions(
    'es_host=s' =>\@es_host,
    'pluritest_file=s' => \$pluritest_filename,
    'cnv_filename=s' => \$cnv_filename,
    'allowed_samples_gtarray=s' => \$allowed_samples_gtarray_file,
    'allowed_samples_gexarray=s' => \$allowed_samples_gexarray_file,
);

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, Search::Elasticsearch->new(nodes => $es_host));
}

my $cell_updated = 0;
my $cell_uptodate = 0;

my %allowed_samples_gtarray;
open my $fh, '<', $allowed_samples_gtarray_file or die "could not open $allowed_samples_gtarray_file: $!";
LINE:
while (my $line = <$fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  next LINE if !$split_line[0] || !$split_line[1];
  $allowed_samples_gtarray{join('_', @split_line[0,1])} = 1;
}
close $fh;

my %allowed_samples_gexarray;
open $fh, '<', $allowed_samples_gexarray_file or die "could not open $allowed_samples_gexarray_file: $!";
LINE:
while (my $line = <$fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  next LINE if !$split_line[0] || !$split_line[1];
  $allowed_samples_gexarray{join('_', @split_line[0,1])} = 1;
}
close $fh;

my %qc1_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
LINE:
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  next LINE if !$allowed_samples_gexarray{$split_line[0]};
  my ($sample) = $split_line[0] =~ /([A-Z]{4}\d{4}[a-z]{1,2}-[a-z]{4}_\d+)_/;
  next LINE if !$sample;
  $qc1_details{$sample}{pluritest}{pluripotency} = $split_line[1];
  $qc1_details{$sample}{pluritest}{novelty} = $split_line[3];
}
close $pluri_fh;

open my $cnv_fh, '<', $cnv_filename or die "could not open $cnv_filename $!";
<$cnv_fh>;
LINE:
while (my $line = <$cnv_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  next LINE if !$allowed_samples_gtarray{$split_line[0]};
  my ($sample) = $split_line[0] =~ /([A-Z]{4}\d{4}[a-z]{1,2}-[a-z]{4}_\d+)_/;
  next LINE if !$sample;
  $qc1_details{$sample}{cnv}{num_different_regions} = $split_line[1];
  $qc1_details{$sample}{cnv}{length_different_regions_Mbp} = $split_line[2];
  $qc1_details{$sample}{cnv}{length_shared_differences} = $split_line[3];
}
close $cnv_fh;

CELL_LINE:
while (my ($ips_name, $qc1_hash) = each %qc1_details) {
  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_name
  );
  next CELL_LINE if !$line_exists;
  my $original = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_name,
  );
  my $update = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_name,
  );
  foreach my $field (keys $qc1_details{$ips_name}){
    foreach my $subfield (keys $qc1_details{$ips_name}{$field}){
      $$update{'_source'}{$field}{$subfield} = $qc1_details{$ips_name}{$field}{$subfield};
    }
  }
  if (Compare($$update{'_source'}, $$original{'_source'})){
    $cell_uptodate++;
  }else{
    $$update{'_source'}{'_indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->index(
        index => 'hipsci',
        type => 'cellLine',
        id => $ips_name,
        body => $$update{'_source'},
      );
    }
    $cell_updated++;
  }
}

print "\n04update_qc1\n";
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
