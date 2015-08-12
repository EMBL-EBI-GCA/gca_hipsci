#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use Text::Capitalize qw();

my $es_host='vg-rs-dev1:9200';
my $demographic_filename;

&GetOptions(
    'es_host=s' =>\$es_host,
    'demographic_file=s' => \$demographic_filename,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
die "did not get a demographic file on the command line" if !$demographic_filename;

my $cgap_donors = read_cgap_report()->{donors};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my %donors;
DONOR:
foreach my $donor (@{$cgap_donors}) {
  next DONOR if !$donor->biosample_id;
  my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
  next DONOR if !$donor_biosample;
  my $donor_name = $donor_biosample->property('Sample Name')->values->[0];
  my $donor_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
  );
  next DONOR if !$donor_exists;


  my $donor_update = {};
  my $cell_line_update = {};
  if (my $disease_property = $donor_biosample->property('disease state')) {
    my $term_source = $disease_property->qualified_values()->[0]->term_source();
    my $purl = $term_source->term_source_id();
    if ($purl !~ /^http:/) {
      $purl = $term_source->uri() . '/' . $purl;
    }
    if ($purl =~ /EFO_0000761/) {
      $purl = 'http://purl.obolibrary.org/obo/PATO_0000461';
    }
    my $disease_value = $purl =~ /PATO_0000461/ ? 'Normal'
                      : $purl =~ /Orphanet_224/ ? 'Neonatal diabetes mellitus'
                      : $purl =~ /Orphanet_110/ ? 'Bardet-Biedl syndrome'
                      : $disease_property->values->[0];
    $donor_update->{diseaseStatus} = {
      value => $disease_value,
      ontologyPURL => $purl,
    };
    $cell_line_update->{diseaseStatus} = $donor_update->{diseaseStatus};
  }
  if (my $sex = $donor->gender) {
    my %sex_hash = (
      value => ucfirst($sex),
      ontologyPURL => $sex eq 'male' ? 'http://www.ebi.ac.uk/efo/EFO_0001266'
                      : $sex eq 'female' ? 'http://www.ebi.ac.uk/efo/EFO_0001265'
                      : undef,
    );
    $donor_update->{sex} = \%sex_hash;
    $cell_line_update->{donor}{sex} = \%sex_hash;
  }
  if (my $age = $donor->age) {
    $donor_update->{age} = $age;
    $cell_line_update->{donor}{age} = $age;
  }
  if (my $ethnicity = $donor->ethnicity) {
    $ethnicity = Text::Capitalize::capitalize($ethnicity);
    $donor_update->{ethnicity} = $ethnicity;
    $cell_line_update->{donor}{ethnicity} = $ethnicity;
  }

  $elasticsearch->update(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
    body => {doc => $donor_update},
  );

  foreach my $tissue (@{$donor->tissues}) {
    CELL_LINE:
    foreach my $cell_line (@{$tissue->ips_lines}) {
      my $line_exists = $elasticsearch->exists(
        index => 'hipsci',
        type => 'cellLine',
        id => $cell_line->name,
      );
      next CELL_LINE if !$line_exists;
      $elasticsearch->update(
        index => 'hipsci',
        type => 'cellLine',
        id => $cell_line->name,
        body => {doc => $cell_line_update},
      );
    }
  }
}
