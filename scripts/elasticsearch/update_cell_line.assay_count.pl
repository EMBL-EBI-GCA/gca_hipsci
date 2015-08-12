#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);

my $es_host='vg-rs-dev1:9200';

&GetOptions(
    'es_host=s' =>\$es_host,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
my $scroll = $elasticsearch->scroll_helper(
    index => 'hipsci',
    search_type => 'scan',
    size => 500,
    type => 'cellLine',
);

my %donor_assays;
CELL_LINE:
while (my $doc = $scroll->next) {
  my $assays = $doc->{_source}{assays};
  next CELL_LINE if !$assays;
  my $assay_count = scalar grep {ref($assays->{$_}) eq 'HASH'} keys %$assays;
  $assays->{count} = $assay_count;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $doc->{_id},
    body => {doc => {assays => $assays}},
  );
  $donor_assays{$doc->{_source}{donor}{name}} += $assay_count;
};

DONOR:
while (my ($donor, $assay_count) = each %donor_assays) {
  $elasticsearch->update(
    index => 'hipsci',
    type => 'donor',
    id => $donor,
    body => {doc => {assays => {count => $assay_count}}},
  );
}
