#!/usr/bin/env perl

use strict;
use warnings;


use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use LWP::Simple qw();
use JSON qw();
use Data::Compare;
use Getopt::Long;
use POSIX qw(strftime);
use Data::Dumper;


my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $epd_find_url = 'https://www.peptracker.com/epd/hipsci_lines/';
my $epd_link_url = 'https://www.peptracker.com/epd/analytics/?section_id=40100',
my $idr_find_url = 'https://idr.openmicroscopy.org/mapr/api/cellline/?orphaned=true&page=%d';
my $idr_link_url = 'https://idr.openmicroscopy.org/mapr/cellline/?value=%s';

&GetOptions(
  'es_host=s' =>\@es_host,
);

my $epd_content = LWP::Simple::get($epd_find_url);
die "error getting $epd_find_url" if !defined $epd_content;
my $epd_lines = JSON::decode_json($epd_content);
# print Dumper($epd_lines);
my $idr_page = 0;
my @idr_lines;
IDR_PAGE:
while(1) {
  $idr_page += 1;
  my $idr_content = LWP::Simple::get(sprintf($idr_find_url, $idr_page));
  die "error getting $idr_find_url" if !defined $idr_content;
  my $idr_lines = JSON::decode_json($idr_content);
  last IDR_PAGE if ! scalar @{$idr_lines->{maps}};
  push(@idr_lines, grep {/^HPSI/} map {$_->{id}} @{$idr_lines->{maps}});
}
print Dumper(@idr_lines);
#
# my %elasticsearch;
# foreach my $es_host (@es_host){
#   $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
# }
#
# my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
#   index       => 'hipsci',
#   type        => 'file',
#   search_type => 'scan',
#   size        => 500
# );
#
# my %ontology_map = (
#   'Proteomics' => 'http://www.ebi.ac.uk/efo/EFO_0002766',
#   'Genotyping array' => 'http://www.ebi.ac.uk/efo/EFO_0002767',
#   'RNA-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
#   'Cellular phenotyping' => 'http://www.ebi.ac.uk/efo/EFO_0005399',
#   'Methylation array' => 'http://www.ebi.ac.uk/efo/EFO_0002759',
#   'Expression array' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
#   'Exome-seq' => 'http://www.ebi.ac.uk/efo/EFO_0005396',
#   'ChIP-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002692',
#   'Whole genome sequencing' => 'http://www.ebi.ac.uk/efo/EFO_0003744',
# );
# my %cell_line_assays;
# while ( my $doc = $scroll->next ) {
#   my $assay = $doc->{_source}{assay}{type};
#   SAMPLE:
#   foreach my $sample (@{$$doc{'_source'}{'samples'}}){
#     $cell_line_assays{$sample->{name}}{$assay} = {name => $assay, ontologyPURL => $ontology_map{$assay}};
#   }
# }
#
# LINE:
# foreach my $epd_line (@$epd_lines) {
#   my $short_name = $epd_line->{label};
#   my $results = $elasticsearch{$es_host[0]}->call('search',
#     index => 'hipsci',
#     type => 'cellLine',
#     body => {
#       query => { match => {'searchable.fixed' => $short_name} }
#     }
#   );
#   next LINE if ! @{$results->{hits}{hits}};
#   $cell_line_assays{$results->{hits}{hits}[0]{_source}{name}}{Proteomics} = {
#       name => 'Proteomics',
#       ontologyPURL =>$ontology_map{Proteomics},
#       peptrackerURL => $epd_link_url,
#     };
# }
#
# LINE:
# foreach my $idr_line (@idr_lines) {
#   $cell_line_assays{$idr_line}{'Cellular phenotyping'} = {
#       name => 'Cellular phenotyping',
#       ontologyPURL =>$ontology_map{'Cellular phenotyping'},
#       idrURL => sprintf($idr_link_url, $idr_line),
#     };
# }
#
# while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
#   my $cell_updated = 0;
#   my $cell_uptodate = 0;
#   my $scroll = $elasticsearchserver->call('scroll_helper',
#     index       => 'hipsci',
#     type        => 'cellLine',
#     search_type => 'scan',
#     size        => 500
#   );
#
#   CELL_LINE:
#   while ( my $doc = $scroll->next ) {
#     my $cell_line  = $doc->{_source}{name};
#     my @new_assays = values %{$cell_line_assays{$cell_line}};
#     next CELL_LINE if Compare(\@new_assays, $doc->{_source}{assays} || []);
#     if (scalar @new_assays) {
#       $doc->{_source}{assays} = \@new_assays;
#     }
#     else {
#       delete $doc->{_source}{assays};
#     }
#     $doc->{_source}{_indexUpdated} = $date;
#     $elasticsearchserver->index_line(id => $doc->{_source}{name}, body => $doc->{_source});
#   }
# }
