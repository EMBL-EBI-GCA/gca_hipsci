#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use File::Basename qw(fileparse);
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my %study_ids;

sub study_id_handler {
  my ($assay_name, $submission_file) = @_;
  push(@{$study_ids{$assay_name}}, $submission_file);
}

&GetOptions(
  'es_host=s' =>\@es_host,
  'gtarray=s' =>\&study_id_handler,
  'gexarray=s' =>\&study_id_handler,
  'mtarray=s' =>\&study_id_handler,
);

my %assay_name_map = (
  gexarray => 'Expression array',
  gtarray => 'Genotyping array',
  mtarray => 'Methylation array',
);
my %ontology_map = (
  gexarray => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  gtarray => 'http://www.ebi.ac.uk/efo/EFO_0002767',
  mtarray => 'http://www.ebi.ac.uk/efo/EFO_0002759',
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $cgap_lines = read_cgap_report()->{ips_lines};

my %cell_line_updates;
while (my ($assay, $submission_files) = each %study_ids) {
  foreach my $submission_file (@$submission_files) {
    my $filename = fileparse($submission_file);
    my ($study_id) = $filename =~ /(EGAS\d+)/;
    die "did not recognise study_id from $submission_file" if !$study_id;
    open my $fh, '<', $submission_file or die "could not open $submission_file $!";
    <$fh>;
    while (my $line = <$fh>) {
      chomp $line;
      my ($sample) = split("\t", $line);
      $cell_line_updates{$sample}{assays}{$assay} = {
        'archive' => 'EGA',
        'study' => $study_id,
        'name' => $assay_name_map{$assay},
        'ontologyPURL' => $ontology_map{$assay},
      };
    }
  }
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $scroll = $elasticsearchserver ->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 500
  );

  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    my $biosample_id = $$doc{'_source'}{'bioSamplesAccession'};
    my $update = $elasticsearchserver ->fetch_line_by_name($$doc{'_source'}{'name'});
    foreach my $key (keys %assay_name_map){
      delete $$update{'_source'}{'assays'}{$key};
    }
    if (! scalar keys $$update{'_source'}{'assays'}){
      delete $$update{'_source'}{'assays'};
    }
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
  print "08update_array_assays\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}