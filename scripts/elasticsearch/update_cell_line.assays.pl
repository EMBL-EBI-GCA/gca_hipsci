#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);

my $es_host='vg-rs-dev1:9200';
my %study_ids;
my @era_params = ('ops$laura', undef, 'ERAPRO');

sub study_id_handler {
  my ($assay_name, $study_id) = @_;
  push(@{$study_ids{$assay_name}}, $study_id);
}

&GetOptions(
    'es_host=s' =>\$es_host,
    'era_password=s'              => \$era_params[1],
          'rnaseq=s' =>\&study_id_handler,
          'chipseq=s' =>\&study_id_handler,
          'exomeseq=s' =>\&study_id_handler,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

my $cgap_lines = read_cgap_report()->{ips_lines};

my $sql_ega =  '
  select sa.biosample_id from sample sa, run r, run_sample rs, experiment e, study st
  where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id and e.study_id=st.study_id
  and st.ega_id=? group by sa.biosample_id
  ';

my $sql_ena =  '
  select sa.biosample_id from sample sa, run r, run_sample rs, experiment e
  where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id
  and e.study_id=? group by sa.biosample_id
  ';


my %cell_line_updates;
my $era_db = get_erapro_conn(@era_params);
my $sth_ega = $era_db->dbc->prepare($sql_ega) or die "could not prepare $sql_ega";
my $sth_ena = $era_db->dbc->prepare($sql_ena) or die "could not prepare $sql_ena";
while (my ($assay, $study_ids) = each %study_ids) {
  foreach my $study_id (@$study_ids) {
    if ($study_id =~ /^EGA/) {
      $sth_ega->bind_param(1, $study_id);
      $sth_ega->execute or die "could not execute";
      while (my $row = $sth_ega->fetchrow_arrayref) {
        $cell_line_updates{$row->[0]}{assays}{$assay} = {
          'archive' => 'EGA',
          'study' => $study_id,
        };
      }
    }
    else {
      $sth_ena->bind_param(1, $study_id);
      $sth_ena->execute or die "could not execute";
      while (my $row = $sth_ena->fetchrow_arrayref) {
        $cell_line_updates{$row->[0]}{assays}{$assay} = {
          'archive' => 'ENA',
          'study' => $study_id,
        };
      }
    }
  }
}


CELL_LINE:
foreach my $ips_line (@{$cgap_lines}) {
  my $biosample_id = $ips_line->biosample_id;
  next CELL_LINE if !$biosample_id;
  next CELL_LINE if !$cell_line_updates{$biosample_id};
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line->name,
  );
  next CELL_LINE if !$line_exists;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line->name,
    body => {doc => $cell_line_updates{$biosample_id}},
  );
}
