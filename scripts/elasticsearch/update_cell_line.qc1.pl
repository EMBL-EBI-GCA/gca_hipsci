#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Data::Compare;
use Clone qw(clone);
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

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

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

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $scroll = $elasticsearchserver->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 500
  );

  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    my $update = clone $doc;
    delete $$update{'_source'}{'cnv'}{num_different_regions};
    delete $$update{'_source'}{'cnv'}{length_different_regions_Mbp};
    delete $$update{'_source'}{'cnv'}{length_shared_differences};
    if (! scalar keys $$update{'_source'}{'cnv'}){
      delete $$update{'_source'}{'cnv'};
    }
    delete $$update{'_source'}{'pluritest'}{pluripotency};
    delete $$update{'_source'}{'pluritest'}{novelty};
    if (! scalar keys $$update{'_source'}{'pluritest'}){
      delete $$update{'_source'}{'pluritest'};
    }
    if ($qc1_details{$$doc{'_source'}{'name'}}){
      foreach my $field (keys $qc1_details{$$doc{'_source'}{'name'}}){
        foreach my $subfield (keys $qc1_details{$$doc{'_source'}{'name'}}{$field}){
          $$update{'_source'}{$field}{$subfield} = $qc1_details{$$doc{'_source'}{'name'}}{$field}{$subfield};
        }
      }
    }
    if (Compare($$update{'_source'}, $$doc{'_source'})){
      $cell_uptodate++;
    }else{
      $$update{'_source'}{'_indexUpdated'} = $date;
      $elasticsearchserver->index_line(id => $$doc{'_source'}{'name'}, body => $$update{'_source'});
      $cell_updated++;
    }
  }
  print "\n$host\n";
  print "\n04update_qc1\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}

