#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $predicted_population_filename = "/nfs/research2/hipsci/drop/hip-drop/tracked/predicted_population/hipsci.pca_557.20170928.predicted_populations.tsv";

&GetOptions(
  'es_host=s' =>\@es_host,
  'predicted_population_filename=s' =>\$predicted_population_filename
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my %population_codes = (
  AFR => "African",
  AMR => "Ad Mixed American",
  EAS => "East Asian",
  EUR => "European",
  SAS => "South Asian"
);

my %predicted_populations;
open my $predpop_fh, '<', $predicted_population_filename or die "could not open $predicted_population_filename $!";
<$predpop_fh>;
LINE:
while (my $line = <$predpop_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $predicted_populations{$split_line[0]} = $population_codes{$split_line[1]};
}
close $predpop_fh;

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_updated = 0;
  my $cell_uptodate = 0;

  my $scroll = $elasticsearchserver->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 500
  );

  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    my $update = clone $doc;
    my $fibroblast_name = $$update{'_source'}{'name'};
    $fibroblast_name =~ s/_.*//;
    my $ipsc_name = $fibroblast_name;
    $ipsc_name =~ s/i-/pf-/;
    delete $$update{'_source'}{'predictedPopulation'};
    if ($predicted_populations{$fibroblast_name}){
      $$update{'_source'}{'predictedPopulation'} = $predicted_populations{$fibroblast_name};
    }
    elsif ($predicted_populations{$ipsc_name}){
      $$update{'_source'}{'predictedPopulation'} = $predicted_populations{$ipsc_name};
    }
    if (Compare($$update{'_source'}, $$doc{'_source'})){
      $cell_uptodate++;
    }else{
      $$update{'_source'}{'_indexUpdated'} = $date;
      $elasticsearchserver->index_line(id => $$doc{'_source'}{'name'}, body => $$update{'_source'});
      $cell_updated++;
    }
  }
  print "\n$host\n";
  print "update_predicted_populations\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}