#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch get_ontology_full);
use Text::Capitalize qw();
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my ($demographic_filename, $sex_filename);

&GetOptions(
  'es_host=s' =>\@es_host,
  'demographic_file=s' => \$demographic_filename,
  'sex_sequenome_file=s' => \$sex_filename,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}
die "did not get a demographic file on the command line" if !$demographic_filename;
die "did not get a sex sequenome file on the command line" if !$sex_filename;

my $cell_updated = 0;
my $cell_uptodate = 0;
my $donor_updated = 0;
my $donor_uptodate = 0;

my $cgap_donors = read_cgap_report()->{donors};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename, sex_sequenome_file => $sex_filename);

my %donors;
my %all_updates_donor;
my %all_update_cellline;

my %cgap_donors_hash;
DONOR:
foreach my $donor (@{$cgap_donors}) {
  next DONOR if !$donor->biosample_id;
  $cgap_donors_hash{$donor->biosample_id}=$donor;
}

my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
);

DONOR:
while ( my $doc = $scroll->next ) {
  my $donor = $cgap_donors_hash{$$doc{'_source'}{'bioSamplesAccession'}};
  my $donor_name = $$doc{'_source'}{'name'};
  my $donor_update = {};
  my $cell_line_update = {};
  if (my $disease = $donor->disease) {
    my $purl = get_ontology_full($disease) or die "did not recognise disease $disease";
    my $disease_value = get_disease_for_elasticsearch($disease) or die "did not recognise disease $disease";

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
  $all_updates_donor{$$doc{'_source'}{'name'}} = $donor_update;
  $all_update_cellline{$$doc{'_source'}{'name'}} = $cell_line_update;
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $donor_updated = 0;
  my $donor_uptodate = 0;
  my $scroll = $elasticsearchserver->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
  );
  while ( my $doc = $scroll->next ) {
    my $donor_update = $all_updates_donor{$$doc{'_source'}{'name'}};
    my $cell_line_update = $all_update_cellline{$$doc{'_source'}{'name'}};
    my $donor = $cgap_donors_hash{$$doc{'_source'}{'bioSamplesAccession'}};
    my $update = clone $doc;
    delete $$update{'_source'}{'diseaseStatus'};
    delete $$update{'_source'}{'sex'};
    delete $$update{'_source'}{'age'};
    delete $$update{'_source'}{'ethnicity'};
    foreach my $field (keys %$donor_update){
      $$update{'_source'}{$field} = $$donor_update{$field};
    }
    if (Compare($$update{'_source'}, $$doc{'_source'})){
      $donor_uptodate++;
    }else{ 
      $$update{'_source'}{'_indexUpdated'} = $date;
        $elasticsearchserver->index_donor(id => $$doc{'_source'}{'name'}, body => $$update{'_source'});
      $donor_updated++;
    }
    foreach my $tissue (@{$donor->tissues}) {
      CELL_LINE:
      foreach my $cell_line(map {$_->name} $tissue, @{$tissue->ips_lines}){
        my $line_exists = $elasticsearchserver->call('exists',
          index => 'hipsci',
          type => 'cellLine',
          id => $cell_line,
        );
        next CELL_LINE if !$line_exists;
        my $original = $elasticsearchserver->fetch_line_by_name($cell_line);
        my $update = clone $original;
        delete $$update{'_source'}{'diseaseStatus'};
        delete $$update{'_source'}{'donor'}{'sex'};
        delete $$update{'_source'}{'donor'}{'age'};
        delete $$update{'_source'}{'donor'}{'ethnicity'};
        if (! scalar keys $$update{'_source'}{'donor'}){
          delete $$update{'_source'}{'donor'};
        }
        foreach my $field (keys %$cell_line_update){
          foreach my $subfield (keys $$cell_line_update{$field}){
            $$update{'_source'}{$field}{$subfield} = $$cell_line_update{$field}{$subfield};
          }     
        }
        if (Compare($$update{'_source'}, $$original{'_source'})){
          $cell_uptodate++;
        }else{
          $$update{'_source'}{'_indexUpdated'} = $date;
          $elasticsearchserver->index_line(id => $cell_line, body => $$update{'_source'});
          $cell_updated++;
        }
      }
    }
  }
  print "\n$host\n";
  print "03_update_demographics\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
  print "Donors: $donor_updated updated, $donor_uptodate unchanged.\n";
}
