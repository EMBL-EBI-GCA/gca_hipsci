#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::EBiSC::hESCreg;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Search::Elasticsearch;
use Getopt::Long;
use List::Util qw();

my ($hESCreg_user, $hESCreg_pass);
my $hescreg_es_host='vg-rs-dev1:9200';
my $hipsci_es_host='ves-pg-e4:9200';

GetOptions("hESCreg_user=s" => \$hESCreg_user,
    "hESCreg_pass=s" => \$hESCreg_pass,
    'hipsci_es_host=s' =>\$hipsci_es_host,
    'hescreg_es_host=s' =>\$hescreg_es_host,
);
die "missing credentials" if !$hESCreg_user || !$hESCreg_pass;

my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
  #host => 'test.hescreg.eu',
  #realm => 'hESCreg Development'
);

my $es_hescreg = Search::Elasticsearch->new(nodes => $hescreg_es_host);
my $es_scroll = $es_hescreg->scroll_helper(
  index => 'hescreg',
  search_type => 'scan',
  type => 'line',
  body => {
    query => {
      filtered => {
        filter => {
          term => {
            'providers.id' => 437,
          }
        }
      }
    }
  }
);

my $es_hipsci = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $hipsci_es_host);

LINE:
while (my $es_doc = $es_scroll->next) {
  my $line = $es_doc->{_source};
  my $ebisc_name = $line->{name};
  next LINE if $ebisc_name !~ /^WTSI/;
  next LINE if !$line->{biosamples_id};
  next LINE if $line->{final_submit_flag};

  my $es_line = $es_hipsci->fetch_line_by_biosample_id($line->{biosamples_id});

  if (!$es_line->{_source}{pluritest}) {
    print "skipping cell line $ebisc_name\n";
    next LINE;
  }

  my $gexarray_files = $es_hipsci->call('search', 
    index => 'hipsci',
    type => 'file',
    body => {
      query => {
        filtered => {
          filter => {
            "and" => [
              { "term" => { 'samples.name' => $es_line->{_source}{name}}},
              { "term" => { 'assay.type' => 'Expression array'}},
            ]
          }
        }
      }
    }
  );

  my %post_hash = (
    cell_line_id => $line->{id},
    pluripotency_score => $es_line->{_source}{pluritest}{pluripotency},
    novelty_score => $es_line->{_source}{pluritest}{novelty},
    ldap_user_id => 'ian.streeter',
    microarray_url => $gexarray_files->{hits}{hits}[0]{_source}{archive}{url},
  );
  
  print $line->{id}, "\n";
  my $response =  $hESCreg->post_pluritest(\%post_hash);
  if ($response =~ /error/i) {
    print $response;
    print encode_json(\%post_hash), "\n";
    exit;
  }
}
