#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Text::Delimited;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::DBSQL::DBAdaptor;
use Getopt::Long;
use List::Util qw();
use File::Find qw();

#my @feeder_free_temp_override = (
  #qw(leeh_3 iakz_1 febc_2 nibo_3 aehn_2 oarz_22 zisa_33 peop_4 dard_2 coxy_33 xisg_33 oomz_22 dovq_33 liun_22 xavk_33 aehn_22 funy_1 funy_3 giuf_1 giuf_3 iill_1 iill_3 bima_1 bima_2 ieki_2 ieki_3 qolg_1 qolg_3 bulb_1 gusc_1 gusc_2 gusc_3)
#);


my $ag_lims_filename;
my $sendai_counts_dir;
my $pluritest_filename;
my $es_host='ves-hx-e4:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
&GetOptions(
  'es_host=s' => \$es_host,
  'pluritest_file=s' => \$pluritest_filename,
  'ag_lims_fields=s' => \$ag_lims_filename,
  'sendai_counts_dir=s' => \$sendai_counts_dir,
  'pluritest_file=s' => \$pluritest_filename,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
);

die "did not get a sendai_counts_dir on the command line" if !$sendai_counts_dir;

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor;

my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>3)}{qw(donors tissues ips_lines)};

my %disallow_pluritest;
my %pluritest_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
LINE:
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  my ($sample) = $split_line[0] =~ /([A-Z]{4}\d{4}[a-z]{1,2}-[a-z]{4}(?:_\d+)?)_/;
  next LINE if !$sample;
  if ($pluritest_details{$sample}) {
    $disallow_pluritest{$sample} = 1;
    next LINE;
  }
  $pluritest_details{$sample} = \@split_line;
}
close $pluri_fh;
LINE:
foreach my $line (keys %pluritest_details) {
  if ($disallow_pluritest{$line}) {
    delete $pluritest_details{$line};
  }
}


my $ag_lims_file = new Text::Delimited;
$ag_lims_file->delimiter(';');
my %ag_lims_fields;
$ag_lims_file->open($ag_lims_filename) or die "could not open $ag_lims_filename $!";
while (my $line_data = $ag_lims_file->read) {
  $ag_lims_fields{$line_data->{'name'}} = $line_data;
}
$ag_lims_file->close;

my %rna_sendai_reads;
File::Find::find(sub {
  return if ! -f $_;
  return if $_ !~ /\.bam$/;
  my ($sample) = split(/\./, $_);
  my $count = `samtools view -c $_`;
  chomp $count;
  $rna_sendai_reads{$sample} = $count;

}, $sendai_counts_dir);

my @output_fields = qw( name cell_type derived_from donor biosample_id tissue_biosample_id
    donor_biosample_id derived_from_cell_type reprogramming gender age disease
    ethnicity
    growing_conditions_gtarray growing_conditions_gexarray
    growing_conditions_mtarray growing_conditions_rnaseq growing_conditions_exomeseq growing_conditions_proteomics
    cnv_num_different_regions cnv_length_different_regions_Mbp cnv_length_shared_differences_Mbp
    pluri_raw pluri_logit_p pluri_novelty pluri_novelty_logit_p pluri_rmsd rnaseq.sendai_reads);
my @ag_lims_output_fields = qw(id_lims id_qc1 id_qc2 time_registration time_purify.somatic
    time_observed.outgrowths time_observed.fibroblasts time_sendai time_episomal time_retrovirus
    time_colony.picking time_split.to.fates time_freeze.for.master.cell.bank time_stain.primary
    time_stain.secondary time_ip.cells time_flow time_transfer.to.feederfree
    phasetime_candidate.ips phasetime_transduction phasetime_confirm.ips phasetime_pipeline.time
    assaytime_gex assaytime_gt assaytime_cellomics assaytime_rnaseq assaytime_methyl
    assaytime_chip assaypassage_gex assaypassage_cellomics assaypassage_methyl
    assaypassage_rnaseq assayuser_gex assayuser_gt assayuser_cellomics assayuser_rnaseq
    assayuser_methyl assayuser_chip assaybatch_gex.beadchip.id assaybatch_gex.array
    assaybatch_gex.plate assaybatch_gex.well assaybatch_gex.batch
    assaybatch_methyl.sentrix.id assaybatch_methyl.sentrix.position assaybatch_methyl.plate
    assaybatch_methyl.well checks_pluritest.raw checks_pluritest.novelty checks_gex.fail
    checks_passage.rate checks_qc2.swap checks_cnvs study_blueprint
    study_reprogramming.comparison study_media.comparison comment_qc1.decision comment_anja friendly);
print join("\t", @output_fields, @ag_lims_output_fields), "\n";

my @output_lines;
DONOR:
foreach my $donor (@$donors) {
  my $donor_name = '';
  if (my $donor_biosample_id = $donor->biosample_id) {
    if (my $es_donor = $elasticsearch->fetch_donor_by_biosample_id($donor_biosample_id)) {
      $donor_name = $es_donor->{_source}{name};
    }
  }
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {

    my $es_line;
    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      next IPS_LINE if !$ips_line->biosample_id;
      next IPS_LINE if $ips_line->name !~ /HPSI/;
      if (my $next_es_line = $elasticsearch->fetch_line_by_name($ips_line->name)) {
        $es_line = $next_es_line;
      }
      else {
        next IPS_LINE;
      }

      my %output = (name => $ips_line->name,
          cell_type => 'iPSC',
          derived_from => $tissue->name,
          donor => $donor_name,
          biosample_id => $ips_line->biosample_id,
          tissue_biosample_id => $tissue->biosample_id,
          donor_biosample_id => $donor->biosample_id,
          derived_from_cell_type => $es_line->{_source}{sourceMaterial}{cellType},
          reprogramming => $es_line->{_source}{reprogramming}{methodOfDerivation},
          gender => lc($es_line->{_source}{donor}{sex}{value} || ''),
          age => $es_line->{_source}{donor}{age},
          disease => $es_line->{_source}{diseaseStatus}{value},
          ethnicity => $es_line->{_source}{donor}{ethnicity},
          cnv_num_different_regions => $es_line->{_source}{cnv}{num_different_regions},
          cnv_length_different_regions_Mbp => $es_line->{_source}{cnv}{length_different_regions_Mbp},
          cnv_length_shared_differences_Mbp => $es_line->{_source}{cnv}{length_shared_differences},
          pluri_raw => $pluritest_details{$ips_line->name}->[1],
          pluri_logit_p => $pluritest_details{$ips_line->name}->[2],
          pluri_novelty => $pluritest_details{$ips_line->name}->[3],
          pluri_novelty_logit_p => $pluritest_details{$ips_line->name}->[4],
          pluri_rmsd => $pluritest_details{$ips_line->name}->[5],
          'rnaseq.sendai_reads' => $rna_sendai_reads{$ips_line->name},
      );
      ASSAY:
      foreach my $assay(qw(gtarray gexarray mtarray rnaseq exomeseq proteomics)) {
        my $release_type = $assay =~ /g.*array/ ? 'qc1' : 'qc2';
        my ($file) = grep {$_->name !~ m{/withdrawn/}} @{$fa->fetch_by_filename('%/'.$assay.'/%/'.$ips_line->name.'/%')};
        next ASSAY if !$file;

        my $date;
        if ($assay eq 'proteomics') {
          $date = $file->created;
        }
        else {
          ($date) = $file->name =~ /\.(\d{8})\./;
        }
        next ASSAY if !$date;

        my $cgap_release = $ips_line->get_release_for(type => $release_type, date =>$date);
        my $growing_conditions = $cgap_release && $cgap_release->is_feeder_free ? 'Feeder-free'
                        : $cgap_release && !$cgap_release->is_feeder_free ? 'Feeder-dependent'
                        : $ips_line->name =~ /_\d\d$/ ? 'Feeder-free'
                        : $ips_line->passage_ips && $ips_line->passage_ips lt 20140000 ? 'Feeder-dependent'
                        : $ips_line->qc1 && $ips_line->qc1 lt 20140000 ? 'Feeder-dependent'
                        : die "could not get growing conditions for ".$file->name;
        $output{'growing_conditions_'.$assay} = $growing_conditions;
      }

      if (my $ips_ag_lims_fields = $ag_lims_fields{$ips_line->name}) {
        foreach my $output_field (@ag_lims_output_fields) {
          if (my $field_val = $ips_ag_lims_fields->{$output_field}) {
            $output{$output_field} = $field_val eq 'NA' ? '' : $field_val;
          }
        }
      };
      my (@sort_parts) = $ips_line->name =~ /\w+(\d\d)(\d\d)\w*-([a-z]+)_(\d+)/;
      push(@output_lines, [\@sort_parts, join("\t", map {$_ // ''} @output{@output_fields, @ag_lims_output_fields})]);

    }
    next TISSUE if !$es_line;
    my %output = (name => $tissue->name,
        cell_type => $es_line->{_source}{sourceMaterial}{cellType},
        biosample_id => $tissue->biosample_id,
        donor => $donor_name,
        donor_biosample_id => $donor->biosample_id,
        gender => lc($es_line->{_source}{donor}{sex}{value} || ''),
        age => $es_line->{_source}{donor}{age},
        disease => $es_line->{_source}{diseaseStatus}{value},
        ethnicity => $es_line->{_source}{donor}{ethnicity},
        pluri_raw => $pluritest_details{$tissue->name}->[1],
        pluri_logit_p => $pluritest_details{$tissue->name}->[2],
        pluri_novelty => $pluritest_details{$tissue->name}->[3],
        pluri_novelty_logit_p => $pluritest_details{$tissue->name}->[4],
        pluri_rmsd => $pluritest_details{$tissue->name}->[5],
        'rnaseq.sendai_reads' => $rna_sendai_reads{$tissue->name},
    );
    if (my $tissue_ag_lims_fields = $ag_lims_fields{$tissue->name}) {
      foreach my $output_field (@ag_lims_output_fields) {
        if (my $field_val = $tissue_ag_lims_fields->{$output_field}) {
          $output{$output_field} = $field_val eq 'NA' ? '' : $field_val;
        }
      }
    };
    my (@sort_parts) = $tissue->name =~ /\w+(\d\d)(\d\d)\w*-([a-z]+)/;
    push(@sort_parts, 0);
    push(@output_lines, [\@sort_parts, join("\t", map {$_ // ''} @output{@output_fields, @ag_lims_output_fields})]);
  }
}
print map {$_->[1], "\n"} sort {
                               $a->[0][1] <=> $b->[0][1]
                            || $a->[0][0] <=> $b->[0][0]
                            || $a->[0][2] cmp $b->[0][2]
                            || $a->[0][3] <=> $b->[0][3]
                                } @output_lines;
