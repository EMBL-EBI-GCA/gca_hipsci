#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
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

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, Search::Elasticsearch->new(nodes => $es_host));
}

my $cell_updated = 0;
my $cell_uptodate = 0;

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


CELL_LINE:
while (my ($ips_line, $lineupdate) = each %cell_line_updates) {
  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  next CELL_LINE if !$line_exists;
  my $original = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  my $update = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  foreach my $key (keys %assay_name_map){
    delete $$update{'_source'}{'assays'}{$key};
  }
  if (! scalar keys $$update{'_source'}{'assays'}){
    delete $$update{'_source'}{'assays'};
  }
  foreach my $field (keys $lineupdate){
    foreach my $subfield (keys $$lineupdate{$field}){
      $$update{'_source'}{$field}{$subfield} = $$lineupdate{$field}{$subfield};
    }
  }
  if (Compare($$update{'_source'}, $$original{'_source'})){
    $cell_uptodate++;
  }else{
    $$update{'_source'}{'_indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->index(
        index => 'hipsci',
        type => 'cellLine',
        id => $ips_line,
        body => $$update{'_source'},
      );
    }
    $cell_updated++;
  }
}

print "\n08update_array_assays\n";
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
