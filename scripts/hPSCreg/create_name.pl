#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::EBiSC::hESCreg;
use Search::Elasticsearch;
use Getopt::Long;

my ($hESCreg_user, $hESCreg_pass, @cell_line_names);
my $es_host='vg-rs-dev1:9200';
my $hipsci_es_host = 'ves-hx-e4:9200';

GetOptions("hESCreg_user=s" => \$hESCreg_user,
    "hESCreg_pass=s" => \$hESCreg_pass,
    "cell_line=s" => \@cell_line_names,
    'es_host=s' =>\$es_host,
);
die "missing credentials" if !$hESCreg_user || !$hESCreg_pass;

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
my $max_id = $elasticsearch->search(
  index => 'hescreg',
  type => 'line',
  body => {
    size => 0,
    aggregations => {
      max_id => {
        max => {
          field => 'id',
        }
      }
    }
  }
)->{aggregations}{max_id}{value};
die "did not get the elasticsearch max id" if !$max_id;

my $hipsci_es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host=>$hipsci_es_host);

my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
  #host => 'test.hescreg.eu',
  #realm => 'hESCreg Development'
);
my ($cgap_ips_lines) =  read_cgap_report()->{ips_lines};

my @hESCreg_lines;
LINE:
foreach my $hESCreg_name (@{$hESCreg->find_lines}) {
  my $line = eval{$hESCreg->get_line($hESCreg_name);};
  next LINE if !$line || $@;
  push(@hESCreg_lines, $line);
}

LINE:
foreach my $hipsci_name (@cell_line_names) {
  my ($cgap_line) = grep {$_->name eq $hipsci_name} @$cgap_ips_lines;
  die "did not find cgap line for $hipsci_name" if !$cgap_line;

  my $es_line = $hipsci_es->fetch_line_by_name($hipsci_name);
  die "did not find es line for $hipsci_name" if !$es_line;

  my $es_response = $elasticsearch->search(
    index => 'hescreg',
    type => 'line',
    body => {
      query => {
        filtered => {
          filter => {
            term => {
              alternate_name => $hipsci_name,
            }
          }
        }
      }
    }
  );
  if ($es_response->{hits}{total}) {
    print join("\t", $hipsci_name, $cgap_line->biosample_id, $es_response->{hits}{hits}->[0]->{_source}{name}, ($es_line->{_source}{ecaccCatalogNumber} || '')), "\n";
    next LINE;
  }

  $es_response = $elasticsearch->search(
    index => 'hescreg',
    type => 'line',
    body => {
      query => {
        filtered => {
          filter => {
            term => {
              biosamples_id => $cgap_line->biosample_id,
            }
          }
        }
      }
    }
  );
  if ($es_response->{hits}{total}) {
    print join("\t", $hipsci_name, $cgap_line->biosample_id, $es_response->{hits}{hits}->[0]->{_source}{name}, ($es_line->{_source}{ecaccCatalogNumber} || '')), "\n";
    next LINE;
  }

  my $same_donor_cell_line_id;
  COUSIN:
  foreach my $cousin_line (grep {$_->name ne $hipsci_name} map {@{$_->ips_lines}} @{$cgap_line->tissue->donor->tissues}) {
    $es_response = $elasticsearch->search(
      index => 'hescreg',
      type => 'line',
      body => {
        query => {
          filtered => {
            filter => {
              term => {
                biosamples_id => $cousin_line->biosample_id,
              }
            }
          }
        }
      }
    );
    next COUSIN if !$es_response->{hits}{total};
    $same_donor_cell_line_id = $es_response->{hits}{hits}->[0]->{_source}{name};
    last COUSIN;
  }
  my $new_name = $hESCreg->create_name(provider_id => 437, same_donor_cell_line_id => $same_donor_cell_line_id);
  print join("\t", $hipsci_name, $cgap_line->biosample_id, $new_name, ($es_line->{_source}{ecaccCatalogNumber} || '')), "\n";

  NEWLINE:
  while ($max_id < 2000) {
    $max_id += 1;
    my $new_line = eval{$hESCreg->get_line($max_id);};
    next LINE if !$new_line || $@;
    if ($new_line->{name} eq $new_name) {
      $new_line->{alternate_name} = [$hipsci_name];
      $new_line->{biosamples_id} = $cgap_line->biosample_id;
    }
    $elasticsearch->index(
      index => 'hescreg',
      type => 'line',
      id => $max_id,
      body => $new_line,
    );
    #Important: Elasticsearch has only *near* real-time search
    sleep(5);
    last NEWLINE if $new_line->{name} eq $new_name;
  }
}
