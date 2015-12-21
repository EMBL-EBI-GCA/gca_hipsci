#!/usr/bin/env perl

use strict;
use warnings;


use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use Data::Compare;
use Getopt::Long;
use POSIX qw(strftime);
use Clone qw(clone);

my $date = strftime('%Y%m%d', localtime);

my @es_host;

&GetOptions(
  'es_host=s' =>\@es_host,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
  index       => 'hipsci',
  type        => 'file',
  search_type => 'scan',
  size        => 500
);

my %assay_name_map = (
  'Proteomics' => 'proteomics',
  'Genotyping array' => 'gtarray',
  'RNA-seq' => 'rnaseq',
  'Cellular phenotyping' => 'cellbiol-fn',
  'Methylation array' => 'mtarray',
  'Expression array' => 'gexarray',
  'Exome-seq' => 'exomeseq',
  'ChIP-seq' => 'chipseq',
);
my %ontology_map = (
  'Proteomics' => 'http://www.ebi.ac.uk/efo/EFO_0002766',
  'Genotyping array' => 'http://www.ebi.ac.uk/efo/EFO_0002767',
  'RNA-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  'Cellular phenotyping' => 'http://www.ebi.ac.uk/efo/EFO_0005399',
  'Methylation array' => 'http://www.ebi.ac.uk/efo/EFO_0002759',
  'Expression array' => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  'Exome-seq' => 'http://www.ebi.ac.uk/efo/EFO_0005396',
  'ChIP-seq' => 'http://www.ebi.ac.uk/efo/EFO_0002692',
);
my %archive_map = (
  'HipSci FTP' => 'FTP',
  'EGA' => 'EGA',
  'ENA' => 'ENA',
  'ArrayExpress' => 'ArrayExpress',
);
my %cell_line_updates;
while ( my $doc = $scroll->next ) {
  SAMPLE:
  foreach my $sample (@{$$doc{'_source'}{'samples'}}){
    my $sample = $$sample{name};
    my $assay = $$doc{'_source'}{assay}{type};
    my @urlparts = split('/', $$doc{'_source'}{archive}{url});
    $cell_line_updates{$sample}{assays}{$assay_name_map{$assay}} = {
        'archive' => $archive_map{$$doc{'_source'}{archive}{name}},
        'name' => $assay,
        'ontologyPURL' => $ontology_map{$assay},
    };
    if ($$doc{'_source'}{archive}{name} ne 'EGA' and $$doc{'_source'}{archive}{name} ne 'ENA'){
      my $ftpurl = $$doc{'_source'}{archive}{url};
      $ftpurl =~ s?ftp\:\/\/ftp\.hipsci\.ebi\.ac\.uk??;
      $ftpurl =~ s?raw_open_data?raw_data?;
      $cell_line_updates{$sample}{assays}{$assay_name_map{$assay}}{path} = $ftpurl;
    }
    #NOTE Condsider including study ID. Would need to look it up in EGA, ENA using dataset ID from files table.
  }
}

#NOTE Non file based linking such as peptracker will need to be added seperately here

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
    delete $$update{'_source'}{'assays'};
    if ($cell_line_updates{$$doc{'_source'}{'name'}}){
      my $lineupdate = $cell_line_updates{$$doc{'_source'}{'name'}};
      foreach my $field (keys $lineupdate){
        foreach my $subfield (keys $$lineupdate{$field}){
          $$update{'_source'}{$field}{$subfield} = $$lineupdate{$field}{$subfield};
        }
      }
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
  print "07_Availible_Files_update\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}