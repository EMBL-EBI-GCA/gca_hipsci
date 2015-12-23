#!/usr/bin/env perl

use strict;
use warnings;


use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use Data::Compare;
use Getopt::Long;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;

&GetOptions(
  'es_host=s' =>\@es_host,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
  index       => 'hipsci',
  type        => 'file',
  search_type => 'scan',
  size        => 500
);

my %ontology_map = (
  'Proteomics' => 'http://www.ebi.ac.uk/efo/EFO_0002766',
  'Genotyping array' => 'http://www.ebi.ac.uk/efo/EFO_0002767',
  'RNA-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  'Cellular phenotyping' => 'http://www.ebi.ac.uk/efo/EFO_0005399',
  'Methylation array' => 'http://www.ebi.ac.uk/efo/EFO_0002759',
  'Expression array' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  'Exome-seq' => 'http://www.ebi.ac.uk/efo/EFO_0005396',
  'ChIP-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002692',
  'Whole genome sequencing' => 'http://www.ebi.ac.uk/efo/EFO_0003744',
);
my %cell_line_assays;
while ( my $doc = $scroll->next ) {
  my $assay = $doc->{_source}{assay}{type};
  SAMPLE:
  foreach my $sample (@{$$doc{'_source'}{'samples'}}){
    $cell_line_assays{$sample->{name}}{$assay} = $ontology_map{$assay};
  }
}


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
    my $cell_line  = $doc->{_source}{name};
    my @new_assays = map {{name => $_, ontologyPURL => $cell_line_assays{$cell_line}{$_}}} keys %{$cell_line_assays{$cell_line}};
    next CELL_LINE if Compare(\@new_assays, $doc->{_source}{assays} || []);
    if (scalar @new_assays) {
      $doc->{_source}{assays} = \@new_assays;
    }
    else {
      delete $doc->{_source}{assays};
    }
    $doc->{_source}{_indexUpdated} = $date;
    $elasticsearchserver->index_line(id => $doc->{_source}{name}, body => $doc->{_source});
  }
}
