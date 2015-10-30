#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use List::Util qw();
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my $cgap_ips_lines = read_cgap_report()->{ips_lines};

my %cgap_tissues;
foreach my $tissue (@{read_cgap_report()->{tissues}}){
  $cgap_tissues{$tissue->name} = $tissue;
}
my @es_host;

&GetOptions(
  'es_host=s' =>\@es_host,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $cell_deleted = 0;
my $cell_uptodate = 0;
my $donor_deleted = 0;
my $donor_uptodate = 0;

my %cellLines;
my %donors;

CELL_LINE:
foreach my $ips_line (@{$cgap_ips_lines}) {
  next CELL_LINE if ! $ips_line->biosample_id;
  next CELL_LINE if $ips_line->name !~ /^HPSI\d{4}i-/;
  $cellLines{$ips_line->biosample_id} = 1;
  $donors{$ips_line->tissue->donor->biosample_id} = 1;
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_created = 0;
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $scroll = $elasticsearchserver->call('scroll_helper',
    index       => 'hipsci',
    type        => 'file',
    search_type => 'scan',
    size        => 500
  );
  TISSUE:
  while ( my $doc = $scroll->next ) {
    SAMPLE:
    foreach my $sample (@{$$doc{'_source'}{'samples'}}){
      next SAMPLE if $$sample{'cellType'} eq 'iPSC';
      my $nonipsc_linename = $$sample{'name'};
      my $tissue = $cgap_tissues{$nonipsc_linename};
      next SAMPLE if ! $tissue->biosample_id;
      $cellLines{$tissue->biosample_id} = 1;
    }
  }
}

my $alert_message = 0;

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $scroll = $elasticsearchserver->call('scroll_helper',
  index       => 'hipsci',
  type        => 'cellLine',
  search_type => 'scan',
  size        => 500
  );
  while ( my $doc = $scroll->next ) {
    if ($cellLines{$$doc{'_source'}{'bioSamplesAccession'}}){
      $cell_uptodate++;
    }else{
      print_alert() if !$alert_message;
      print "curl -XDELETE http://$host/hipsci/$$doc{'_type'}/$$doc{'_source'}{'name'}\n";
      $cell_deleted++;
    }
  }
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $scroll = $elasticsearchserver->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
  );
  while ( my $doc = $scroll->next ) {
    if ($donors{$$doc{'_source'}{'bioSamplesAccession'}}) {
      $donor_uptodate++;
    }else{
      print_alert() if !$alert_message;
      print "curl -XDELETE http://$host/hipsci/$$doc{'_type'}/$$doc{'_source'}{'name'}\n";
      $donor_deleted++;
    }
  }
}

sub print_alert {
  print "\nThis is an alert that cell lines or donors are in HipSci Elasticsearch but not in the latest report provided by CGaP.\n\n";
  print "The following are the identified missing cell lines and donors, please confirm that they are to be deleted with CGaP and then run the following commands to remove them from ElasticSearch if required:\n\n";
  $alert_message = 1;
}