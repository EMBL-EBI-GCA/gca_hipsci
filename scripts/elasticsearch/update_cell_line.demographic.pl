#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use Text::Capitalize qw();
use Data::Compare;

use POSIX qw(strftime);
my $date = strftime('%Y%m%d', localtime);

my $es_host='vg-rs-dev1:9200';
my $demographic_filename;

&GetOptions(
    'es_host=s' =>\$es_host,
    'demographic_file=s' => \$demographic_filename,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
die "did not get a demographic file on the command line" if !$demographic_filename;

my $cell_updated = 0;
my $cell_uptodate = 0;
my $donor_updated = 0;
my $donor_uptodate = 0;

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
  if (my $disease = $donor->disease) {
    my $purl = $disease eq 'normal' ? 'http://purl.obolibrary.org/obo/PATO_0000461'
                : $disease =~ /bardet-/ ? 'http://www.orpha.net/ORDO/Orphanet_110'
                : $disease eq 'neonatal diabetes' ? 'http://www.orpha.net/ORDO/Orphanet_224'
                : die "did not recognise disease $disease";
    my $disease_value = $disease eq 'normal' ? 'Normal'
                : $disease =~ /bardet-/ ? 'Bardet-Biedl syndrome'
                : $disease eq 'neonatal diabetes' ? 'Neonatal diabetes mellitus'
                : die "did not recognise disease $disease";

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
    my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
  );
  my $original = $elasticsearch->get(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
  );
  $donor_update->{'indexCreated'} = $$original{'_source'}{'indexCreated'};
  $donor_update->{'indexUpdated'} = $$original{'_source'}{'indexUpdated'};
  if (Compare($donor_update, $$original{'_source'})){
    $donor_uptodate++;
  }else{ 
    $donor_update->{'indexUpdated'} = $date;
    $elasticsearch->update(
      index => 'hipsci',
      type => 'donor',
      id => $donor_name,
      body => {doc => $donor_update},
    );
    $donor_updated++;
  }

  foreach my $tissue (@{$donor->tissues}) {
    CELL_LINE:
    foreach my $cell_line (@{$tissue->ips_lines}) {
      my $line_exists = $elasticsearch->exists(
        index => 'hipsci',
        type => 'cellLine',
        id => $cell_line->name,
      );
      next CELL_LINE if !$line_exists;
      my $original = $elasticsearch->get(
        index => 'hipsci',
        type => 'cellLine',
        id => $cell_line->name,
      );
      $cell_line_update->{'indexCreated'} = $$original{'_source'}{'indexCreated'};
      $cell_line_update->{'indexUpdated'} = $$original{'_source'}{'indexUpdated'};
      if (Compare($cell_line_update, $$original{'_source'})){
        $cell_uptodate++;
      }else{
        $cell_line_update->{'indexUpdated'} = $date;
        $elasticsearch->update(
          index => 'hipsci',
          type => 'cellLine',
          id => $cell_line->name,
          body => {doc => $cell_line_update},
        );
        $cell_updated++;
      }
    }
  }
}
#TODO  Should send this to a log file
print "\n02update_demographics\n"
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
print "Donors: $donor_updated updated, $donor_uptodate unchanged.\n";