#!/usr/bin/env perl
# requires json files associated with IDR data to get the cell line names.
# The files should be the same ones used to load IDR file data to elasticsearch in script/indexes/idr_data.es.pl
# The path to the file needs to be called $filename, smilar to line 28, 29. IDR0034 and IDR0037 have been completed.

use strict;
use warnings;


use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use LWP::Simple qw();
use JSON qw();
use Data::Compare;
use Getopt::Long;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my $es_host='ves-hx-e3:9200';
my $epd_find_url = 'https://www.peptracker.com/epd/hipsci_lines/';
my $epd_link_url = 'https://www.peptracker.com/epd/analytics/?section_id=40100',
my $idr_find_url = 'https://idr.openmicroscopy.org/mapr/api/cellline/?orphaned=true&page=%d';
my $idr_link_url = 'https://idr.openmicroscopy.org/mapr/cellline/?value=%s';

# my $filename = '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_1901.json';  # IDR json file for 'idr0034-kilpinen-hipsci/screenA'
my $filename = '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_2051.json';  # IDR json file for 'idr0037-vigilante-hipsci/screenA'

my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $json = JSON->new;
my $data = $json->decode($json_text);
my @IDR_celllines; # cellline for the particular IDR like idr0034
my @experiment_array = keys %$data;
foreach my $experiment (@experiment_array) {
   foreach my $celllines ($data->{$experiment}{'Cell line'}) {
      foreach my $cellline (@$celllines) {
         push(@IDR_celllines, $cellline)
      }
   }
}

my $epd_content = LWP::Simple::get($epd_find_url);
die "error getting $epd_find_url" if !defined $epd_content;
my $epd_lines = JSON::decode_json($epd_content);

my $idr_page = 0;
my @idr_lines;
IDR_PAGE:
while(1) {
  $idr_page += 1;
  my $idr_content = LWP::Simple::get(sprintf($idr_find_url, $idr_page));
  die "error getting $idr_find_url" if !defined $idr_content;
  my $idr_lines = JSON::decode_json($idr_content);
  last IDR_PAGE if ! scalar @{$idr_lines->{maps}};
  push(@idr_lines, grep {/^HPSI/} map {$_->{id}} @{$idr_lines->{maps}});
}

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $scroll = $elasticsearch->call('scroll_helper',
  index       => 'hipsci',
  type        => 'file',
  search_type => 'scan',
  size        => 500
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
  'Whole genome sequencing' => 'http://www.ebi.ac.uk/efo/EFO_0003744',
  'High content imaging'    => 'http://www.ebi.ac.uk/efo/EFO_0007550',
);
my %cell_line_assays;
while ( my $doc = $scroll->next ) {
  my $assay = $doc->{_source}{assay}{type};
  SAMPLE:
  foreach my $sample (@{$$doc{'_source'}{'samples'}}){
    $cell_line_assays{$sample->{name}}{$assay} = {name => $assay, ontologyPURL => $ontology_map{$assay}};
  }
}

LINE:
foreach my $epd_line (@$epd_lines) {
  my $short_name = $epd_line->{label};
  my $results = $elasticsearch{$es_host[0]}->call('search',
    index => 'hipsci',
    type => 'cellLine',
    body => {
      query => { match => {'searchable.fixed' => $short_name} }
    }
  );
  next LINE if ! @{$results->{hits}{hits}};
  $cell_line_assays{$results->{hits}{hits}[0]{_source}{name}}{Proteomics} = {
      name => 'Proteomics',
      ontologyPURL =>$ontology_map{Proteomics},
      peptrackerURL => $epd_link_url,
    };
}

LINE:
foreach my $idr_line (@idr_lines) {
  $cell_line_assays{$idr_line}{'Cellular phenotyping'} = {
      name => 'Cellular phenotyping',
      ontologyPURL =>$ontology_map{'Cellular phenotyping'},
      idrURL => sprintf($idr_link_url, $idr_line),
    };
}

LINE:
foreach my $idr (@IDR_celllines) {
  $cell_line_assays{$idr}{'High content imaging'} = {
      name => 'High content imaging',
      ontologyPURL =>$ontology_map{'High content imaging'},
      # idrURL => sprintf($idr_link_url, $idr),
    };
}

my $new_scroll = $elasticsearch->call('scroll_helper',
  index       => 'hipsci',
  type        => 'cellLine',
  search_type => 'scan',
  size        => 500
);

CELL_LINE:
while ( my $doc = $new_scroll->next ) {
  my $cell_line  = $doc->{_source}{name};
  my @new_assays = values %{$cell_line_assays{$cell_line}};
  next CELL_LINE if Compare(\@new_assays, $doc->{_source}{assays} || []);
  if (scalar @new_assays) {
    $doc->{_source}{assays} = \@new_assays;
  }
  else {
    delete $doc->{_source}{assays};
  }
  $doc->{_source}{_indexUpdated} = $date;
  $elasticsearch->index_line(id => $doc->{_source}{name}, body => $doc->{_source});
}
