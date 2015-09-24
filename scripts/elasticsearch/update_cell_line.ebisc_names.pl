#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $ebisc_name_file;

&GetOptions(
    'es_host=s' =>\@es_host,
    'ebisc_name_file=s' =>\$ebisc_name_file,
);

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, Search::Elasticsearch->new(nodes => $es_host));
}

my $cell_updated = 0;
my $cell_uptodate = 0;

open my $fh, '<', $ebisc_name_file or die "could not open $ebisc_name_file $!";
<$fh>;
CELL_LINE:
while (my $line = <$fh>) {
  chomp $line;
  my ($ebisc_name, $hipsci_name) = split("\t", $line);
  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $hipsci_name,
  );
  next CELL_LINE if !$line_exists;
    my $original = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $hipsci_name,
  );
  my $update = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $hipsci_name,
  );
  $$update{'_source'}{'ebiscName'} = $ebisc_name;
  if (Compare($$update{'_source'}, $$original{'_source'})){
    $cell_uptodate++;
  }else{
    $$update{'_source'}{'_indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->update(
        index => 'hipsci',
        type => 'cellLine',
        id => $hipsci_name,
        body => {doc => $$update{'_source'}},
      );
    }
    $cell_updated++;
  }
}

print "\n10update_ebisc_name\n";
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";