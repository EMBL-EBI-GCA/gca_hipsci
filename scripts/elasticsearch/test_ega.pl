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
    print Dumper($disease);
}
#   my $name = $cohort{disease}{value};
#   my $id = lc($name);
#   $id =~ s/[^\w]/-/g;
#
#   $cohort{datasets} = [];
#   $cohort{name} = $name;
#
#   my $donor_search  = $es->call('search',
#     index => 'hipsci',
#     type => 'donor',
#     body => {
#       query => {
#         constant_score => {
#           filter => {
#             term => {'diseaseStatus.value' => $cohort{disease}{value}},
#           }
#         }
#       },
#     },
#     size => 0,
#   );
#   $cohort{donors} = {count => $donor_search->{hits}{total}};
#
#   foreach my $assay (@assays) {
#
#     my $search  = $es->call('search',
#       index => 'hipsci',
#       type => 'file',
#       body => {
#         query => {
#           constant_score => {
#             filter => {
#               bool => {
#                 must => [
#                   {term => {'samples.diseaseStatus' => $cohort{disease}{value}}},
#                   {term => {'assay.type' => $assay}},
#                   {term => {'archive.name' => 'EGA'}},
#                 ]
#               }
#             }
#           }
#         }
#       }
#     );
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