#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use BioSD;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Data::Compare;

use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

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

my %cgap_tissues;
foreach my $tissue (@{read_cgap_report()->{tissues}}){
  $cgap_tissues{$tissue->name} = $tissue;
}

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host));
}

my $cell_created = 0;
my $cell_updated = 0;
my $cell_uptodate = 0;

TISSUE:
foreach my $nonipsc_linename ($elasticsearch[0]->fetch_non_ipsc_names()){
  next TISSUE if $nonipsc_linename !~ /^HPSI/;
  my $tissue = $cgap_tissues{$nonipsc_linename};
  next TISSUE if ! $tissue->biosample_id;
  my $biosample = BioSD::fetch_sample($tissue->biosample_id); 
  my $donor = $tissue->donor;
  my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
  my $tissue_biosample = BioSD::fetch_sample($tissue->biosample_id);
  my $sample_index = {};

  $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
  $sample_index->{'bioSamplesAccession'} = $tissue->biosample_id;
  $sample_index->{'donor'} = {name => $donor_biosample->property('Sample Name')->values->[0],
                            bioSamplesAccession => $donor->biosample_id};

  if (my $cell_type_property = $tissue_biosample->property('cell type')) {
    my $cell_type_qual_val = $cell_type_property->qualified_values()->[0];
    my $cell_type_purl = $cell_type_qual_val->term_source()->term_source_id();
    if ($cell_type_purl !~ /^http:/) {
      $cell_type_purl = $cell_type_qual_val->term_source()->uri() . $cell_type_purl;
    }
    $sample_index->{'cellType'}->{value} = ucfirst(lc($cell_type_qual_val->value()));
    $sample_index->{'cellType'}->{ontologyPURL} = $cell_type_purl;
  }

  if (my $biomaterial_provider = $biomaterial_provider_hash{$donor->hmdmc}) {
    $sample_index->{'tissueProvider'} = $biomaterial_provider;
  }
  $sample_index->{'openAccess'} = $open_access_hash{$donor->hmdmc};


  my $line_exists = $elasticsearch[0]->call('exists',
    index => 'hipsci',
    type => 'cellLine',
    id => $nonipsc_linename,
  );
  if ($line_exists){
    my $original = $elasticsearch[0]->fetch_line_by_name($nonipsc_linename);
    my $update = $elasticsearch[0]->fetch_line_by_name($nonipsc_linename);
    delete $$update{'_source'}{'name'}; 
    delete $$update{'_source'}{'bioSamplesAccession'}; 
    delete $$update{'_source'}{'donor'}{'name'}; 
    delete $$update{'_source'}{'donor'}{'bioSamplesAccession'};
    if (! scalar keys $$update{'_source'}{'donor'}){
      delete $$update{'_source'}{'donor'};
    }
    delete $$update{'_source'}{'cellType'}{'value'};
    delete $$update{'_source'}{'cellType'}{'ontologyPURL'};
    if (! scalar keys $$update{'_source'}{'cellType'}){
      delete $$update{'_source'}{'cellType'};
    }
    delete $$update{'_source'}{'tissueProvider'}; 
    delete $$update{'_source'}{'openAccess'};
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
      $$update{'_source'}{'_indexUpdated'} = $date;
      foreach my $elasticsearchserver (@elasticsearch){
        $elasticsearchserver->index_line(id => $sample_index->{name}, body => $$update{'_source'});
      }
      $cell_updated++;
    }
  }else{
    $sample_index->{'_indexCreated'} = $date;
    $sample_index->{'_indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->index_line(id => $sample_index->{name}, body => $sample_index);
    }
    $cell_created++;
  }
}

print "\n12populate_fibroblast_line\n";
print "File cell lines: $cell_created created, $cell_updated updated, $cell_uptodate unchanged.\n";
