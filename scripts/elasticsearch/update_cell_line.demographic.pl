#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);

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
  my $donor_name = $donor_biosample->property('Sample Name')->values->[0];
  my $donor_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
  );
  next DONOR if !$donor_exists;


  my $donor_update = {};
  my $cell_line_update = {};
  if (my $disease = $donor->disease) {
    $donor_update->{diseaseStatus} = $disease;
    $cell_line_update->{diseaseStatus} = $disease;
  }
  if (my $sex = $donor->gender) {
    $donor_update->{sex} = $sex;
    $cell_line_update->{sex} = $sex;
  }
  if (my $age = $donor->age) {
    $donor_update->{age} = $age;
    $cell_line_update->{donorAge} = $age;
  }
  if (my $ethnicity = $donor->ethnicity) {
    $donor_update->{ethnicity} = $ethnicity;
    $cell_line_update->{ethnicity} = $ethnicity;
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
