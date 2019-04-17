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
    my %cohort = (
        disease => {
            ontologyPURL => $disease->{ontology_full},
            value        => $disease->{for_elasticsearch},
        },
    );
    # print Dumper($disease);
    # $VAR1 = {
    #       'ontology_full' => 'http://www.orpha.net/ORDO/Orphanet_98664',
    #       'ontology_short' => 'Orphanet:98664',
    #       'regex' => qr/(?^i:macular dystrophy)/,
    #       'for_elasticsearch' => 'Genetic macular dystrophy'
    #     };
    my $name = $cohort{disease}{value};
    # print Dumper($name);
    # $VAR1 = 'Normal';
    # $VAR1 = 'Bardet-Biedl syndrome';
    my $id = lc($name);
    $id =~ s/[^\w]/-/g;
    # print Dumper($id);
    # $VAR1 = 'normal';
    # $VAR1 = 'bardet-biedl-syndrome';
    $cohort{datasets} = [];
    $cohort{name} = $name;

    my $donor_search = $es->call('search',
        index => 'hipsci',
        type  => 'donor',
        body  => {
            query => {
                constant_score => {
                    filter => {
                        term => { 'diseaseStatus.value' => $cohort{disease}{value} },
                    }
                }
            },
        },
        size  => 0,
    );
    # print Dumper($disease);
    # $VAR1 = {
    #       'ontology_full' => 'http://www.orpha.net/ORDO/Orphanet_71859',
    #       'ontology_short' => 'Orphanet:71859',
    #       'regex' => qr/(?^i:neurological disorder)/,
    #       'for_elasticsearch' => 'Rare genetic neurological disorder'
    #     };
    #
    # print Dumper($donor_search);
    # $VAR1 = {
    #       'hits' => {
    #                   'hits' => [],
    #                   'max_score' => '0',
    #                   'total' => 6
    #                 },
    #       'timed_out' => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
    #       '_shards' => {
    #                      'failed' => 0,
    #                      'successful' => 5,
    #                      'total' => 5
    #                    },
    #       'took' => 1
    #     };
    $cohort{donors} = { count => $donor_search->{hits}{total} };
    # print Dumper($cohort{donors});
#     $VAR1 = {
#           'count' => 450
#         };
#     $VAR1 = {
#           'count' => 50
#         };


  foreach my $assay (@assays) {

      my $search = $es->call('search',
          index => 'hipsci',
          type  => 'file',
          body  => {
              query => {
                  constant_score => {
                      filter => {
                          bool => {
                              must => [
                                  { term => { 'samples.diseaseStatus' => $cohort{disease}{value} } },
                                  { term => { 'assay.type' => $assay } },
                                  { term => { 'archive.name' => 'EGA' } },
                              ]
                          }
                      }
                  }
              }
          }
      );
      print Dumper($search);
  }
#     if ($search->{hits}{total}) {
#       my $accession = $search->{hits}{hits}[0]{_source}{archive}{accession};
#       push(@{$cohort{datasets}}, {
#         assay => $assay,
#         archive => 'EGA',
#         accession => $accession,
#         accessionType => 'DATASET_ID',
#         url => "https://ega-archive.org/datasets/$accession",
#       });
#     }
#   }
#
#   $es->call('index',
#     index => 'hipsci',
#     type => 'cohort',
#     id => $id,
#     body => \%cohort,
#   );
# }