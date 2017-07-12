#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Data::Compare;
use YAML::XS qw();
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my @yaml_files;

&GetOptions(
  'es_host=s' =>\@es_host,
  'yaml=s' => \@yaml_files,
);

my %line_diffs;;
foreach my $file (@yaml_files) {
  my $diff = YAML::XS::LoadFile($file) or die $!;
  my $links = delete $diff->{links};
  foreach my $link (@$links) {
    my $cell_lines = delete $link->{lines};
    foreach my $line (@$cell_lines) {
      $line_diffs{$line}{$file} //= {%$diff, links => []};
      push(@{$line_diffs{$line}{$file}{links}}, $link);
    }
  }

}

foreach my $es_host (@es_host){
  my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

  my $scroll = $es->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 500
  );

  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    my $update = clone $doc;
    delete $update->{_source}{differentiations};
    if (my $line_diff = $line_diffs{$doc->{_source}{name}}){
      $update->{_source}{differentiations} = [values %$line_diff];
    }
    if (! Compare($update->{_source}, $doc->{_source})){
      $update->{_source}{_indexUpdated} = $date;
      $es->index_line(id => $doc->{_id}, body => $update->{_source});
    }
  }

}
