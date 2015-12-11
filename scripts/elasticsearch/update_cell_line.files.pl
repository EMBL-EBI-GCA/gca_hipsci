#!/usr/bin/env perl

use strict;
use warnings;


use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use Data::Compare;
use Getopt::Long;
use POSIX qw(strftime);
use Data::Dumper;

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


my %cell_line_updates;
while ( my $doc = $scroll->next ) {
  SAMPLE:
  foreach my $sample (@{$$doc{'_source'}{'samples'}}){
    my $sample = $$sample{name};
    my $assay = $$doc{'_source'}{assay}{type};
    $cell_line_updates{$sample}{assays}{$assay} {
        #TODO FILL THESE IN
        'archive' => 'EGA',
        'study' => $study_id,
        'name' => $assay_name_map{$assay},
        'ontologyPURL' => $ontology_map{$assay},
    };
  }
}