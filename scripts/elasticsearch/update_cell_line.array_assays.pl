#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use File::Basename qw(fileparse);
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);

my $es_host='vg-rs-dev1:9200';
my %study_ids;

sub study_id_handler {
  my ($assay_name, $submission_file) = @_;
  push(@{$study_ids{$assay_name}}, $submission_file);
}

&GetOptions(
    'es_host=s' =>\$es_host,
          'gtarray=s' =>\&study_id_handler,
          'gexarray=s' =>\&study_id_handler,
          'mtarray=s' =>\&study_id_handler,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

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
        };
      }
  }
}


CELL_LINE:
while (my ($ips_line, $cell_line_update) = each %cell_line_updates) {
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  next CELL_LINE if !$line_exists;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
    body => {doc => $cell_line_update},
  );
}
