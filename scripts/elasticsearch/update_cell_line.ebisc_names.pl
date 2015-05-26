#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;

my $es_host='vg-rs-dev1:9200';
my $ebisc_name_file;

&GetOptions(
    'es_host=s' =>\$es_host,
    'ebisc_name_file=s' =>\$ebisc_name_file,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);



open my $fh, '<', $ebisc_name_file or die "could not open $ebisc_name_file $!";
<$fh>;
CELL_LINE:
while (my $line = <$fh>) {
  chomp $line;
  my ($ebisc_name, $hipsci_name) = split("\t", $line);
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $hipsci_name,
  );
  next CELL_LINE if !$line_exists;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $hipsci_name,
    body => {doc => {ebiscName => $ebisc_name}},
  );
}
