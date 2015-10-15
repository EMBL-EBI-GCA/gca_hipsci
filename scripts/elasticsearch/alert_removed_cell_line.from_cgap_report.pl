#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use Search::Elasticsearch;
use List::Util qw();
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my $cgap_ips_lines = read_cgap_report()->{ips_lines};
my @es_host;

&GetOptions(
  'es_host=s' =>\@es_host,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = Search::Elasticsearch->new(nodes => $es_host);
}

my $cell_deleted = 0;
my $cell_uptodate = 0;
my $donor_deleted = 0;
my $donor_uptodate = 0;

my @cellLines;
my @donors;

CELL_LINE:
foreach my $ips_line (@{$cgap_ips_lines}) {
  next CELL_LINE if ! $ips_line->biosample_id;
  next CELL_LINE if $ips_line->name !~ /^HPSI/;
  push(@cellLines, $ips_line->biosample_id);
  push(@donors, $ips_line->tissue->donor->biosample_id);
}

my $alert_message = 0;

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $scroll = $elasticsearchserver->scroll_helper(
    index       => 'hipsci',
    search_type => 'scan',
    size        => 500
  );
  while ( my $doc = $scroll->next ) {
    if ($$doc{'_type'} eq 'cellLine') {
      if ($$doc{'_source'}{'bioSamplesAccession'} ~~ @cellLines){
        $cell_uptodate++;
      }else{
        print_alert() if !$alert_message;
        print "curl -XDELETE http://$host/hipsci/$$doc{'_type'}/$$doc{'_source'}{'name'}\n";
        $cell_deleted++;
      }
    }elsif ($$doc{'_type'} eq 'donor') {
      if ($$doc{'_source'}{'bioSamplesAccession'} ~~ @donors) {
        $donor_uptodate++;
      }else{
        print_alert() if !$alert_message;
        print "curl -XDELETE http://$host/hipsci/$$doc{'_type'}/$$doc{'_source'}{'name'}\n";
        $donor_deleted++;
      }
    }
  }
}

sub print_alert {
  print "\nThis is an alert that cell lines or donors are in HipSci Elasticsearch but not in the latest report provided by CGaP.\n\n";
  print "The following are the identified missing cell lines and donors, please confirm that they are to be deleted with CGaP and then run the following commands to remove them from ElasticSearch if required:\n\n";
  $alert_message = 1;
}