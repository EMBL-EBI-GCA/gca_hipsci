#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use BioSD;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my %biomaterial_provider_hash = (
  'H1288' => 'Cambridge BioResource',
  '13_042' => 'Cambridge BioResource',
  '13_058' => 'University College London',
  '14_001' => 'University College London',
  '14_025' => 'University of Exeter Medical School',
  '14_036' => 'NIH Human Embryonic Stem Cell Registry',
  '15_097' => 'University College London',
  '15_098' => 'University College London',
  '15_099' => 'University of Manchester',
  '15_093' => 'University College London',
  '16_010' => 'University College London',
  '16_011' => 'University College London',
  '16_013' =>  'University College London',
  '16_014' =>  'University of Manchester',
  '16_015' =>  'Cambridge BioResource',
  '16_019' =>  'Cambridge BioResource',
  '16_027' =>  'University College London',
  '16_028' =>  'University College London',
);
my %open_access_hash = (
  'H1288' => 0,
  '13_042' => 1,
  '13_058' => 0,
  '14_001' => 0,
  '14_025' => 0,
  '14_036' => 0,
  '15_097' => 0,
  '15_098' => 0,
  '15_099' => 0,
  '15_093' => 0,
  '16_010' => 0,
  '16_011' => 0,
  '16_013' => 0,
  '16_014' => 0,
  '16_015' => 0,
  '16_019' => 0,
  '16_027' => 0,
  '16_028' => 0,
);

&GetOptions(
    'es_host=s' =>\@es_host,
);

my %cgap_tissues;
foreach my $tissue (@{read_cgap_report()->{tissues}}){
  $cgap_tissues{$tissue->name} = $tissue;
}

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my %nonipsc_celllines;
my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
  index       => 'hipsci',
  type        => 'file',
  search_type => 'scan',
  size        => 500
);
TISSUE:
while ( my $doc = $scroll->next ) {
  SAMPLE:
  foreach my $sample (@{$$doc{'_source'}{'samples'}}){
    next SAMPLE if $$sample{'cellType'} eq 'iPSC';
    my $nonipsc_linename = $$sample{'name'};
    my $tissue = $cgap_tissues{$nonipsc_linename};
    next SAMPLE if ! $tissue->biosample_id;
    my $biosample = BioSD::fetch_sample($tissue->biosample_id);
    next SAMPLE if !$biosample;
    $nonipsc_celllines{$nonipsc_linename}=1;
  }
}
my %all_samples;
foreach my $nonipsc_linename (keys %nonipsc_celllines){
  my $tissue = $cgap_tissues{$nonipsc_linename};
  my $biosample = BioSD::fetch_sample($tissue->biosample_id);
  my $donor = $tissue->donor;
  my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
  my $tissue_biosample = BioSD::fetch_sample($tissue->biosample_id);
  my $source_material = $tissue->tissue_type;
  my $sample_index = {};

  $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
  $sample_index->{'bioSamplesAccession'} = $tissue->biosample_id;
  $sample_index->{'donor'} = {name => $donor_biosample->property('Sample Name')->values->[0],
                            bioSamplesAccession => $donor->biosample_id};

  $sample_index->{'sourceMaterial'} = {
    value => $source_material,
  };

  if (my $cell_type_property = $tissue_biosample->property('cell type')) {
    my $cell_type_qual_val = $cell_type_property->qualified_values()->[0];
    my $cell_type_purl = $cell_type_qual_val->term_source()->term_source_id();
    if ($cell_type_purl !~ /^http:/) {
      $cell_type_purl = $cell_type_qual_val->term_source()->uri() . $cell_type_purl;
    }
    if (ucfirst(lc($cell_type_qual_val->value())) eq "Pbmc"){
      $sample_index->{'sourceMaterial'}->{cellType} = "PBMC";
    }else{
      $sample_index->{'sourceMaterial'}->{cellType} = ucfirst(lc($cell_type_qual_val->value()));
    }
    $sample_index->{'sourceMaterial'}->{ontologyPURL} = $cell_type_purl;
    $sample_index->{'cellType'}->{value} = ucfirst(lc($cell_type_qual_val->value()));
    $sample_index->{'cellType'}->{ontologyPURL} = $cell_type_purl;
  }

  if (my $biomaterial_provider = $biomaterial_provider_hash{$donor->hmdmc}) {
    $sample_index->{'tissueProvider'} = $biomaterial_provider;
  }
  $sample_index->{'openAccess'} = $open_access_hash{$donor->hmdmc};
  $all_samples{$nonipsc_linename} = $sample_index;
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_created = 0;
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  foreach my $nonipsc_linename (keys %nonipsc_celllines){
    my $sample_index = $all_samples{$nonipsc_linename};
    my $line_exists = $elasticsearchserver->call('exists',
      index => 'hipsci',
      type => 'cellLine',
      id => $nonipsc_linename,
    );
    if ($line_exists){
      my $original = $elasticsearchserver->fetch_line_by_name($nonipsc_linename);
      my $update = clone $original;
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
      delete $$update{'_source'}{'sourceMaterial'}; 
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
        $elasticsearchserver->index_line(id => $sample_index->{name}, body => $$update{'_source'});
        $cell_updated++;
      }
    }else{
      $sample_index->{'_indexCreated'} = $date;
      $sample_index->{'_indexUpdated'} = $date;
      $elasticsearchserver->index_line(id => $sample_index->{name}, body => $sample_index);
      $cell_created++;
    }
  }
  print "\n$host\n";
  print "02_populate_fibroblast_line\n";
  print "File cell lines: $cell_created created, $cell_updated updated, $cell_uptodate unchanged.\n";
}
