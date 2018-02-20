#!/usr/bin/env perl

use strict;
use warnings;

use WWW::Mechanize;
use JSON -support_by_pp;
use Data::Dumper;



#Search for project hipsci
my $searchurl = "https://www.ebi.ac.uk/biosamples/samples?size=1000&sort=id,asc&text=&filter=attr%3Aproject%3AHipSci&filter=attr%3Acell+type%3Ainduced+pluripotent+stem+cell";
my @samples = fetch_biosamples_json($searchurl);

my %biosamplestofix;
foreach my $sample (@samples){
  identify_missing_fields(\%biosamplestofix, $sample, 'Sex');
  identify_missing_fields(\%biosamplestofix, $sample, 'age');
  identify_missing_fields(\%biosamplestofix, $sample, 'ethnicity');
  identify_missing_fields(\%biosamplestofix, $sample, 'subject id');
  identify_missing_fields(\%biosamplestofix, $sample, 'phenotype');
  identify_missing_fields(\%biosamplestofix, $sample, 'disease state');
}

foreach my $key (keys(%biosamplestofix)){
  my $sampleurl = "https://www.ebi.ac.uk/biosamples/samples/".$key;
  my $cellline = fetch_json_by_url($sampleurl);
  print Dumper($cellline);
  exit(0);
}

#age
#Sex
#subject id
#ethnicity
#phenotype
#disease state

sub identify_missing_fields{
  my ($biosamplestofix, $sample, $field) = @_;
  if (! $$sample{characteristics}{$field}){
    if ($biosamplestofix{$$sample{accession}}){
      push($biosamplestofix{$$sample{accession}}, $field);
    }else{
      $biosamplestofix{$$sample{accession}} = [$field];
    }
  }
  return $biosamplestofix;
}

#use BioSample API to retrieve BioSample records
sub fetch_biosamples_json{
  my ($json_url) = @_;

  my $json_text = &fetch_json_by_url($json_url);
  my @biosamples;
  # Store the first page 
  foreach my $item (@{$json_text->{_embedded}{samples}}){ 
    push(@biosamples, $item);
  }
  # Store each additional page
  while ($$json_text{_links}{next}{href}){  # Iterate until no more pages using HAL links
    $json_text = fetch_json_by_url($$json_text{_links}{next}{href});# Get next page
    foreach my $item (@{$json_text->{_embedded}{samples}}){
      push(@biosamples, $item);  
    }
  }
  return @biosamples;
}

sub fetch_json_by_url{
  my ($json_url) = @_;

  my $browser = WWW::Mechanize->new();
  #$browser->show_progress(1);  # Enable for WWW::Mechanize GET logging
  $browser->get( $json_url );
  my $content = $browser->content();
  my $json = new JSON;
  my $json_text = $json->decode($content);
  return $json_text;
}