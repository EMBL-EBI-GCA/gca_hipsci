#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my %study_ids;
my @era_params = ('ops$laura', undef, 'ERAPRO');

sub study_id_handler {
  my ($assay_name, $study_id) = @_;
  push(@{$study_ids{$assay_name}}, $study_id);
}

&GetOptions(
    'es_host=s' =>\@es_host,
    'era_password=s'              => \$era_params[1],
    'rnaseq=s' =>\&study_id_handler,
    'chipseq=s' =>\&study_id_handler,
    'exomeseq=s' =>\&study_id_handler,
);

my %assay_name_map = (
  rnaseq => 'RNA-seq',
  exomeseq => 'Exome-seq',
  chipseq => 'ChIP-seq',
);
my %ontology_map = (
  rnaseq => 'http://www.ebi.ac.uk/efo/EFO_0002770',
  exomeseq => 'http://www.ebi.ac.uk/efo/EFO_0005396',
  chipseq => 'http://www.ebi.ac.uk/efo/EFO_0002692',
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

my $cgap_lines = read_cgap_report()->{ips_lines};

my $sql_ega =  '
  select sa.biosample_id from sample sa, run r, run_sample rs, experiment e, study st, run_ega_dataset rd
  where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id and e.study_id=st.study_id
  and rd.run_id=r.run_id
  and st.ega_id=? group by sa.biosample_id
  ';

my $sql_ena =  '
  select sa.biosample_id from sample sa, run r, run_sample rs, experiment e
  where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id
  and r.status_id=4
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
          'name' => $assay_name_map{$assay},
          'ontologyPURL' => $ontology_map{$assay},
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
          'name' => $assay_name_map{$assay},
          'ontologyPURL' => $ontology_map{$assay},
        };
      }
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
    my $biosample_id = $$doc{'_source'}{'bioSamplesAccession'};
    my $update = clone $doc;
    foreach my $key (keys %assay_name_map){
      delete $$update{'_source'}{'assays'}{$key};
    }
    if (! scalar keys $$update{'_source'}{'assays'}){
      delete $$update{'_source'}{'assays'};
    }
    if ($cell_line_updates{$biosample_id}){
      foreach my $field (keys $cell_line_updates{$biosample_id}){
        foreach my $subfield (keys $cell_line_updates{$biosample_id}{$field}){
          $$update{'_source'}{$field}{$subfield} = $cell_line_updates{$biosample_id}{$field}{$subfield};
        }
      }
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
  print "03update_assays\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}