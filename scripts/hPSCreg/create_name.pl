#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::EBiSC::hESCreg;
use Search::Elasticsearch;
use Getopt::Long;

my ($hESCreg_user, $hESCreg_pass, @cell_line_names);
my $es_host='vg-rs-dev1:9200';

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

my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
  host => 'test.hescreg.eu',
  realm => 'hESCreg Development'
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
  next LINE if $es_response->{hits}{total};
  my ($cgap_line) = grep {$_->name eq $hipsci_name} @$cgap_ips_lines;
  die "did not find cgap line for $hipsci_name" if !$cgap_line;

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
  next LINE if $es_response->{hits}{total};

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
                alternate_name => $cousin_line->name,
              }
            }
          }
        }
      }
    );
    print $cousin_line->name, "\n";
    $same_donor_cell_line_id = $es_response->{hits}{hits}->[0]->{_source}{name};
    last COUSIN;
  }
  my $new_name = $hESCreg->create_name(provider_id => 437, same_donor_cell_line_id => $same_donor_cell_line_id);
  #print $new_name, "\n";

  my $new_line_id;
  NEWLINE:
  foreach my $id (($max_id+1)..2000) {
    my $new_line = eval{$hESCreg->get_line($id);};
    next LINE if !$new_line || $@;
    $elasticsearch->index(
      index => 'hescreg',
      type => 'line',
      id => $id,
      body => $new_line,
    );
    if ($new_line->{name} eq $new_name) {
      $new_line_id = $id;
      last NEWLINE;
    }
  }

  my $new_line = eval{$hESCreg->get_line($new_line_id);};

  my $post_hash = $hESCreg->blank_post_hash();
  $post_hash->{biosamples_id} = $cgap_line->biosample_id;
  $post_hash->{biosamples_donor_id} = $cgap_line->tissue->donor->biosample_id;
  $post_hash->{form_finished_flag} .= 1;
  $post_hash->{migration_status} .= 1;
  $post_hash->{final_name_generated_flag} .= 1;
  $post_hash->{final_submit_flag} .= 0;
  $post_hash->{id} .= $new_line->{id};
  $post_hash->{validation_status} .= 3;
  $post_hash->{name} = $new_name;
  push(@{$post_hash->{alternate_name}}, $hipsci_name);
  $post_hash->{type} .= 1;
  $post_hash->{donor_number} = $new_name =~ /WTSIi(\d+)/ ? $1 +0 : die "no donor number for $new_name";
  $post_hash->{donor_cellline_number} .= $new_name =~ /-([A-Z]+)/ ? ord($1) - 64 : die "no donor cellline number for $new_name";
  $post_hash->{donor_cellline_subclone_number} .= 0;
  $post_hash->{same_donor_cell_line_flag} = $new_line->{same_donor_cell_line_flag};
  $post_hash->{same_donor_derived_from_flag} = $new_line->{same_donor_derived_from_flag};
  $post_hash->{provider_generator} .= 437;
  $post_hash->{provider_owner} .= 437;

  print $new_line_id, "\n";
  print $hESCreg->post_line($post_hash), "\n";
}
