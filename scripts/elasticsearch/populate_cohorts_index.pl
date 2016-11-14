#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;

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

my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $scroll = $es->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
);

my %cohorts;
DONOR:
while ( my $doc = $scroll->next ) {
  my $disease = $doc->{_source}{diseaseStatus};
  $cohorts{$disease->{value}}{donors}{count} += 1;
  $cohorts{$disease->{value}}{disease} //= $disease;
}

foreach my $cohort (values %cohorts) {
  my $name = $cohort->{disease}{value};
  if ($name eq 'Normal') {
    $name = 'Normal, managed access';
  }
  $cohort->{datasets} = [];
  $cohort->{name} = $name;
  my $id = $name;
  $id =~ s/[^\w]/-/g;

  foreach my $assay (@assays) {

    my $search  = $es->call('search',
      index => 'hipsci',
      type => 'file',
      body => {
        query => {
          constant_score => {
            filter => {
              bool => {
                must => [
                  {term => {'samples.diseaseStatus' => $cohort->{disease}{value}}},
                  {term => {'assay.type' => $assay}},
                  {term => {'archive.name' => 'EGA'}},
                ]
              }
            }
          }
        }
      }
    );
    if ($search->{hits}{total}) {
      my $accession = $search->{hits}{hits}[0]{_source}{archive}{accession};
      push(@{$cohort->{datasets}}, {
        assay => $assay,
        archive => 'EGA',
        accession => $accession,
        accessionType => 'DATASET_ID',
        url => "https://ega-archive.org/datasets/$accession",
      });
    }
  }

  $es->call('index', 
    index => 'hipsci',
    type => 'cohort',
    id => $id,
    body => $cohort,
  );
}

