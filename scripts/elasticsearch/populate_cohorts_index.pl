#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::DiseaseParser;
use Data::Dumper;


my $es_host = 'ves-hx-e4:9200';

&GetOptions(
  'es_host=s' =>\$es_host,
);

my @assays = (
  'Genotyping array',
  'Expression array',
  'Exome-seq',
  'RNA-seq',
  'Methylation array',
);

my $diseases = \@ReseqTrack::Tools::HipSci::DiseaseParser::diseases;

my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

foreach my $disease (@ReseqTrack::Tools::HipSci::DiseaseParser::diseases) {
  if ($disease->{for_elasticsearch} ne 'Rare genetic neurological disorder') {
      print Dumper($disease->{for_elasticsearch});

  };
}

