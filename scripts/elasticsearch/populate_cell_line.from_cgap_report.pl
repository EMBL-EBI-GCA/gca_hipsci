#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use BioSD;
use Search::Elasticsearch;
use List::Util qw();
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my $cgap_ips_lines = read_cgap_report()->{ips_lines};
my @es_host;
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
    'es_host=s' =>\@es_host,
);
my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, Search::Elasticsearch->new(nodes => $es_host));
}

my $cell_created = 0;
my $cell_updated = 0;
my $cell_uptodate = 0;
my $donor_created = 0;
my $donor_updated = 0;
my $donor_uptodate = 0;

my %donors;
CELL_LINE:
foreach my $ips_line (@{$cgap_ips_lines}) {
  next CELL_LINE if ! $ips_line->biosample_id;
  next CELL_LINE if $ips_line->name !~ /^HPSI/;
  my $biosample = BioSD::fetch_sample($ips_line->biosample_id);
  next CELL_LINE if !$biosample;
  my $tissue = $ips_line->tissue;
  my $donor = $tissue->donor;
  my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
  my $tissue_biosample = BioSD::fetch_sample($tissue->biosample_id);
  my $source_material = $tissue->tissue_type;

#FIXME###############################################################
  # FOR TESTING MUST REMOVE FOR PERODUCTION DEPLOYMENT
  next CELL_LINE if ($$biosample{_id} eq 'SAMEA3282740'); #  Ignore Pulk1
#FIXME###############################################################

  my $sample_index = {};
  $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
  $sample_index->{'bioSamplesAccession'} = $ips_line->biosample_id;
  $sample_index->{'donor'} = {name => $donor_biosample->property('Sample Name')->values->[0],
                            bioSamplesAccession => $donor->biosample_id};
  $sample_index->{'sourceMaterial'} = {
    value => $source_material,
  };
  if (my $cell_type_property = $tissue_biosample->property('cell type')) {
    my $cell_type_qual_val = $cell_type_property->qualified_values()->[0];
    my $cell_type_purl = $cell_type_qual_val->term_source()->term_source_id();
    if ($cell_type_purl !~ /^http:/) {
      $cell_type_purl = $cell_type_qual_val->term_source()->uri() . '/' . $cell_type_purl;
    }
    $sample_index->{'sourceMaterial'}->{cellType} = ucfirst(lc($cell_type_qual_val->value()));
    $sample_index->{'sourceMaterial'}->{ontologyPURL} = $cell_type_purl;
  }

  if (my $growing_conditions_property = $biosample->property('growing conditions')) {
    my $growing_conditions = $growing_conditions_property->values->[0];
    my $growing_conditions_qc1 = $growing_conditions =~ /feeder/i ? 'Feeder dependent' : 'E8 media';
    my $growing_conditions_qc2 = $growing_conditions =~ /E8 media/i ? 'E8 media' : 'Feeder dependent';
    $sample_index->{'growingConditionsQC1'} = $growing_conditions_qc1;
    $sample_index->{'growingConditionsQC2'} = $growing_conditions_qc2;

    if ($growing_conditions_qc2 =~ /E8/) {
      $sample_index->{'culture'} = {
        medium => 'E8 media',
        passageMethod => 'EDTA clump passaging',
        surfaceCoating => 'vitronectin',
        CO2 => '5%',
      };
    }
    elsif ($growing_conditions_qc2 =~ /feeder/i) {
      $sample_index->{'culture'} = {
        medium => 'KOSR',
        passageMethod => 'collagenase and dispase',
        surfaceCoating => 'Mouse embryo fibroblast (MEF) feeder cells',
        CO2 => '5%',
      };
    }
  }
  if (my $method_property = $biosample->property('method of derivation')) {
    my $method_of_derivation = $method_property->values->[0];

    if ($method_of_derivation =~ /cytotune/i) {
      $sample_index->{'reprogramming'} = {
        methodOfDerivation => $method_of_derivation,
        type => 'non-integrating virus',
        virus => 'sendai',
      }
    }
    elsif ($method_of_derivation =~ /episomal/i) {
      $sample_index->{'reprogramming'} = {
        methodOfDerivation => $method_of_derivation,
        type => 'non-integrating vector',
        vector => 'episomal',
      }
    }
    elsif ($method_of_derivation =~ /retrovirus/i) {
      $sample_index->{'reprogramming'} = {
        methodOfDerivation => $method_of_derivation,
        type => 'integrating virus',
        virus => 'retrovirus',
      }
    }
  }
  if (my $date_property = $biosample->property('date of derivation')) {
    $sample_index->{'reprogramming'}{'dateOfDerivation'} = $date_property->values->[0];
  }

  if (my $biomaterial_provider = $biomaterial_provider_hash{$donor->hmdmc}) {
    $sample_index->{'tissueProvider'} = $biomaterial_provider;
  }
  $sample_index->{'openAccess'} = $open_access_hash{$donor->hmdmc};

  my @bankingStatus;
  push(@bankingStatus, 'Banked at ECACC') if 0;
  push(@bankingStatus, 'Banked at EBiSC') if 0;
  if ($ips_line->selected_for_genomics) {
    push(@bankingStatus, 'Selected for banking');
  }
  elsif (List::Util::any {$_->selected_for_genomics} @{$tissue->ips_lines}) {
    push(@bankingStatus, 'Not selected');
  }
  else {
    push(@bankingStatus, 'Pending selection');
  }
  push(@bankingStatus, 'Shipped to ECACC') if $ips_line->ecacc && $sample_index->{'openAccess'};
  $sample_index->{'bankingStatus'} = \@bankingStatus;


  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $sample_index->{name}
  );
  if ($line_exists){
    my $original = $elasticsearch[0]->get(
      index => 'hipsci',
      type => 'cellLine',
      id => $sample_index->{name},
    );
    my $update = $elasticsearch[0]->get(
      index => 'hipsci',
      type => 'cellLine',
      id => $sample_index->{name},
    );
    foreach my $field (keys %$sample_index){
      my $subfield = $$sample_index{$field};
      if (ref($subfield) eq 'HASH'){
        foreach my $subfield (keys $$sample_index{$field}){
          $$update{'_source'}{$field}{$subfield} = $$sample_index{$field}{$subfield};
        }
      }else{
        $$update{'_source'}{$field} = $$sample_index{$field};
      }
    }
    if (Compare($$update{'_source'}, $$original{'_source'})){
      $cell_uptodate++;
    }else{ 
      $$update{'_source'}{'indexUpdated'} = $date;
      foreach my $elasticsearchserver (@elasticsearch){
        $elasticsearchserver->update(
          index => 'hipsci',
          type => 'cellLine',
          id => $sample_index->{name},
          body => {doc => $$update{'_source'}},
        );
      }
      $cell_updated++;
    }
  }else{
    $sample_index->{'indexCreated'} = $date;
    $sample_index->{'indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->index(
        index => 'hipsci',
        type => 'cellLine',
        id => $sample_index->{name},
        body => $sample_index,
      );
    }
    $cell_created++;
  }

  $donors{$sample_index->{donor}{name}} //= {};
  my $donor_index = $donors{$sample_index->{donor}{name}};
  $donor_index->{name} = $sample_index->{donor}{name};
  $donor_index->{'bioSamplesAccession'} = $donor->biosample_id;
  #if (!$donor_index->{'cellLines'} || ! grep {$_ eq $sample_index->{'name'}} @{$donor_index->{'cellLines'}}) {
  #  push(@{$donor_index->{'cellLines'}}, $sample_index->{'name'});
  #}
  if (!$donor_index->{'cellLines'} || ! grep {$_->{'name'} eq $sample_index->{'name'}} @{$donor_index->{'cellLines'}}) {
    push(@{$donor_index->{'cellLines'}}, {name =>$sample_index->{'name'}, bankingStatus => $sample_index->{'bankingStatus'}});
  }
  $donor_index->{'tissueProvider'} = $sample_index->{tissueProvider};

}

while (my ($donor_name, $donor_index) = each %donors) {
  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
  );
  if ($line_exists){
    my $original = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
    );
    my $update = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
    );
    foreach my $field (keys %$donor_index){
      my $subfield = $$donor_index{$field};
      if (ref($subfield) eq 'HASH'){
        foreach my $subfield (keys $$donor_index{$field}){
          $$update{'_source'}{$field}{$subfield} = $$donor_index{$field}{$subfield};
        }
      }else{
        $$update{'_source'}{$field} = $$donor_index{$field};
      }
    }
    if (Compare($$update{'_source'}, $$original{'_source'})){
      $donor_uptodate++;
    }else{ 
      $$update{'_source'}{'indexUpdated'} = $date;
      foreach my $elasticsearchserver (@elasticsearch){
        $elasticsearchserver->update(
          index => 'hipsci',
          type => 'donor',
          id => $donor_name,
          body => {doc => $$update{'_source'}},
        );
      }
      $donor_updated++;
    }
  }else{
    $donor_index->{'indexCreated'} = $date;
    $donor_index->{'indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->index(
        index => 'hipsci',
        type => 'donor',
        id => $donor_name,
        body => $donor_index,
      );
    }
    $donor_created++;
  }
}
#TODO  Should send this to a log file
print "\n01populate_from_cgap\n";
print "Cell lines: $cell_created created, $cell_updated updated, $cell_uptodate unchanged.\n";
print "Donors: $donor_created created, $donor_updated updated, $donor_uptodate unchanged.\n";