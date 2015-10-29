#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::EBiSC::hESCreg;
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my ($ebisc_name_file, $hESCreg_user, $hESCreg_pass);

&GetOptions(
  'es_host=s' =>\@es_host,
  "hESCreg_user=s" => \$hESCreg_user,
  "hESCreg_pass=s" => \$hESCreg_pass,
);
die "missing credentials" if !$hESCreg_user || !$hESCreg_pass;

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
);

my %ebisc_names;
LINE:
foreach my $ebisc_name (@{$hESCreg->find_lines(url=>"/api/full_list/hipsci")}) {
  if ($ebisc_name =~ /^WTSI/){
    my $line = eval{$hESCreg->get_line($ebisc_name);};
    next LINE if !$line || $@;
    my $alternate_names = $line->{alternate_name};
    my $hipsci_name;
    foreach my $name (@$alternate_names){
      if ($name  =~ /^HPSI/){
        die "HipSci line $hipsci_name already defined. More than one hipsci name in line record $ebisc_name" if $hipsci_name;
        $hipsci_name = $name;
      }
    }
    if ($hipsci_name){
      $ebisc_names{$hipsci_name} = $ebisc_name;
    }
  }
}
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
    my $update = $elasticsearchserver->fetch_line_by_name($$doc{'_source'}{'name'});
    delete $$update{'_source'}{'ebiscName'};
    if ($ebisc_names{$$doc{'_source'}{'name'}}){
      $$update{'_source'}{'ebiscName'} = $ebisc_names{$$doc{'_source'}{'name'}};
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
  print "\n10update_ebisc_name\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}