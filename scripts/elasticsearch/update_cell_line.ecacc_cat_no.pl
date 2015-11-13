#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $ecacc_index_file;

&GetOptions(
  'es_host=s' =>\@es_host,
  'ecacc_index_file=s'      => \$ecacc_index_file,
);

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host));
}

open my $fh, '<', $ecacc_index_file or die "could not open $ecacc_index_file $!";
LINE:
while (my $line = <$fh>) {
  next LINE if $line =~ /^#/;
  chomp $line;
  my ($cell_line, $ecacc_cat_no) = split("\t", $line);
  ES:
  foreach my $elasticsearch (@elasticsearch) {
    my $es_line = $elasticsearch->fetch_line_by_name($cell_line);
    next ES if !$es_line || $@;
    next ES if $es_line->{_source}{ecaccCatalogNumber} && $es_line->{_source}{ecaccCatalogNumber} == $ecacc_cat_no;
    $es_line->{_source}{_indexUpdated} = $date;
    $es_line->{_source}{ecaccCatalogNumber} = $ecacc_cat_no;
    $elasticsearch->index_line(id => $es_line->{_id}, body => $es_line->{_source});
  }
}
close $fh;
