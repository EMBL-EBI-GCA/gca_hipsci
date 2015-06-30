#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use BioSD;
use Search::Elasticsearch;
use List::Util qw();

my $cgap_ips_lines = read_cgap_report()->{ips_lines};
my $es_host='vg-rs-dev1:9200';
my %biomaterial_provider_hash = (
  'H1288' => 'Cambridge BioResource',
  '13_042' => 'Cambridge BioResource',
  '13_058' => 'University College London',
  '14_001' => 'University College London',
  '14_025' => 'University of Exeter Medical School',
);
my %open_access_hash = (
  'H1288' => 0,
  '13_042' => 1,
  '13_058' => 0,
  '14_001' => 0,
  '14_025' => 0,
);

&GetOptions(
    'es_host=s' =>\$es_host,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

my %donors;
CELL_LINE:
foreach my $ips_line (@{$cgap_ips_lines}) {
  next CELL_LINE if ! $ips_line->biosample_id;
  my $biosample = BioSD::fetch_sample($ips_line->biosample_id);
  next CELL_LINE if !$biosample;
  my $tissue = $ips_line->tissue;
  my $donor = $tissue->donor;
  my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
  my $source_material = $tissue->tissue_type;

  my $sample_index = {};
  $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
  $sample_index->{'bioSamplesAccession'} = $ips_line->biosample_id;
  $sample_index->{'sourceMaterial'} = $source_material;
  $sample_index->{'donor'} = $donor_biosample->property('Sample Name')->values->[0];

  if (my $growing_conditions_property = $biosample->property('growing conditions')) {
    my $growing_conditions = $growing_conditions_property->values->[0];
    my $growing_conditions_qc1 = $growing_conditions =~ /feeder/i ? 'Feeder dependent' : 'E8 media';
    my $growing_conditions_qc2 = $growing_conditions =~ /E8 media/i ? 'E8 media' : 'Feeder dependent';
    $sample_index->{'growingConditionsQC1'} = $growing_conditions_qc1;
    $sample_index->{'growingConditionsQC2'} = $growing_conditions_qc2;
  }
  if (my $method_property = $biosample->property('method of derivation')) {
    $sample_index->{'methodOfDerivation'} = $method_property->values->[0];
  }
  if (my $date_property = $biosample->property('date of derivation')) {
    $sample_index->{'dateOfDerivation'} = $date_property->values->[0];
  }

  if (my $biomaterial_provider = $biomaterial_provider_hash{$donor->hmdmc}) {
    $sample_index->{'tissueProvider'} = $biomaterial_provider;
  }
  $sample_index->{'openAccess'} = $open_access_hash{$donor->hmdmc};

  $sample_index->{'bankingStatus'} =
          $ips_line->ecacc && $sample_index->{'openAccess'} ? 'Banked'
        : $ips_line->selected_for_genomics ? 'Selected'
        : (List::Util::any {$_->selected_for_genomics} @{$tissue->ips_lines}) ? 'Not selected'
        : 'Pending';

  $elasticsearch->index(
    index => 'hipsci',
    type => 'cellLine',
    id => $sample_index->{name},
    body => $sample_index,
    );

  $donors{$sample_index->{donor}} //= {};
  my $donor_index = $donors{$sample_index->{donor}};
  $donor_index->{name} = $sample_index->{donor};
  $donor_index->{'bioSamplesAccession'} = $donor->biosample_id;
  if (!$donor_index->{'cellLines'} || ! grep {$_ eq $sample_index->{'name'}} @{$donor_index->{'cellLines'}}) {
    push(@{$donor_index->{'cellLines'}}, $sample_index->{'name'});
  }
  $donor_index->{'tissueProvider'} = $sample_index->{tissueProvider};
  
}
while (my ($donor_name, $donor_index) = each %donors) {
  $elasticsearch->index(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
    body => $donor_index,
    );
}
