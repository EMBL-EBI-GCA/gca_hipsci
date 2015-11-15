#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $ecacc_index_file;

&GetOptions(
  'es_host=s' =>\@es_host,
  'ecacc_index_file=s'      => \$ecacc_index_file,
);

my %catalog_numbers;
open my $fh, '<', $ecacc_index_file or die "could not open $ecacc_index_file $!";
LINE:
while (my $line = <$fh>) {
  next LINE if $line =~ /^#/;
  chomp $line;
  my ($cell_line, $ecacc_cat_no) = split("\t", $line);
  $catalog_numbers{$cell_line} = $ecacc_cat_no;
}
close $fh;

foreach my $es_host (@es_host){
  my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

  my $scroll = $es->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 100,
    body => {
      query => {
        filtered => {
          filter => {
            exists => {
              field => 'ecaccCatalogNumber'
      } } } } }
      );
  my %indexed_lines;
  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    if (!$catalog_numbers{$doc->{_id}} || $doc->{_source}{ecaccCatalogNumber} ne $catalog_numbers{$doc->{_id}}) {
      $doc->{_source}{ecaccCatalogNumber} = $catalog_numbers{$doc->{_id}};
      $doc->{_source}{_indexUpdated} = $date;
      $es->index_line(id => $doc->{_id}, body => $doc->{_source});
    }
    $indexed_lines{$doc->{_id}} = 1;
  }

  CELL_LINE:
  while (my ($cell_line, $catalog_number) = each %catalog_numbers) {
    next CELL_LINE if $indexed_lines{$cell_line};
    my $es_line = $es->fetch_line_by_name($cell_line);
    next CELL_LINE if !$es_line || $@;
    $es_line->{_source}{_indexUpdated} = $date;
    $es_line->{_source}{ecaccCatalogNumber} = $catalog_number;
    $es->index_line(id => $es_line->{_id}, body => $es_line->{_source});
  }
}

