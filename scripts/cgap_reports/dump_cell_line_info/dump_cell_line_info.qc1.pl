#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors improve_tissues improve_ips_lines);
use Text::Delimited;
use DBI;
use Getopt::Long;
use BioSD;
use List::Util qw();
use File::Find qw();

#my @feeder_free_temp_override = (
  #qw(leeh_3 iakz_1 febc_2 nibo_3 aehn_2 oarz_22 zisa_33 peop_4 dard_2 coxy_33 xisg_33 oomz_22 dovq_33 liun_22 xavk_33 aehn_22 funy_1 funy_3 giuf_1 giuf_3 iill_1 iill_3 bima_1 bima_2 ieki_2 ieki_3 qolg_1 qolg_3 bulb_1 gusc_1 gusc_2 gusc_3)
#);

my $demographic_filename;
my $growing_conditions_filename;
my $cnv_filename;
my $pluritest_filename;
my $gtarray_allowed_samples_filename;
my $gexarray_allowed_samples_filename;
my $ag_lims_filename;
my $sendai_counts_dir;
&GetOptions(
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
  'pluritest_file=s' => \$pluritest_filename,
  'cnv_filename=s' => \$cnv_filename,
  'gtarray_allowed_samples_filename=s' => \$gtarray_allowed_samples_filename,
  'gexarray_allowed_samples_filename=s' => \$gexarray_allowed_samples_filename,
  'ag_lims_fields=s' => \$ag_lims_filename,
  'sendai_counts_dir=s' => \$sendai_counts_dir,
);

die "did not get a demographic file on the command line" if !$demographic_filename;
die "did not get a sendai_counts_dir on the command line" if !$sendai_counts_dir;

my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>3)}{qw(donors tissues ips_lines)};
$donors = improve_donors(donors=>$donors, demographic_file=>$demographic_filename);
$tissues = improve_tissues(tissues=>$tissues);
$ips_lines = improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file =>$growing_conditions_filename);

my %gtarray_allowed_samples;
open my $qc1_fh, '<', $gtarray_allowed_samples_filename or die "could not open $gtarray_allowed_samples_filename $!";
LINE:
while (my $line = <$qc1_fh>) {
  chomp $line;
  my @split_line =split("\t", $line);
  next LINE if !$split_line[0] || !$split_line[1];
  $gtarray_allowed_samples{join('_', @split_line[0,1])} = $split_line[0];
}
close $qc1_fh;

my %gexarray_allowed_samples;
open $qc1_fh, '<', $gexarray_allowed_samples_filename or die "could not open $gexarray_allowed_samples_filename $!";
LINE:
while (my $line = <$qc1_fh>) {
  chomp $line;
  my @split_line =split("\t", $line);
  next LINE if !$split_line[0] || !$split_line[1];
  $gexarray_allowed_samples{join('_', @split_line[0,1])} = $split_line[0];
}
close $qc1_fh;

my %cnv_details;
open my $cnv_fh, '<', $cnv_filename or die "could not open $cnv_filename $!";
<$cnv_fh>;
LINE:
while (my $line = <$cnv_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  my $allowed_cell_line = $gtarray_allowed_samples{$split_line[0]};
  next LINE if !$allowed_cell_line;
  $cnv_details{$allowed_cell_line} = \@split_line;
}
close $cnv_fh;

my %pluritest_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
LINE:
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  my $allowed_cell_line = $gexarray_allowed_samples{$split_line[0]};
  next LINE if !$allowed_cell_line;
  $pluritest_details{$allowed_cell_line} = \@split_line;
}
close $pluri_fh;

my $ag_lims_file = new Text::Delimited;
$ag_lims_file->delimiter(';');
my %ag_lims_fields;
$ag_lims_file->open($ag_lims_filename) or die "could not open $demographic_filename $!";
while (my $line_data = $ag_lims_file->read) {
  $ag_lims_fields{$line_data->{'id_public.name'}} = $line_data;
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
    study_reprogramming.comparison study_media.comparison comment_qc1.decision comment_anja);
print join("\t", @output_fields, @ag_lims_output_fields), "\n";

my @output_lines;
DONOR:
foreach my $donor (@$donors) {
  my $donor_name = '';
  if (my $donor_biosample_id = $donor->biosample_id) {
    if (my $donor_biosample = BioSD::fetch_sample($donor_biosample_id)) {
      $donor_name = $donor_biosample->property('Sample Name')->values->[0];
    }
  }
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {
    my $tissue_has_data = 0;

    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      next IPS_LINE if !$ips_line->biosample_id;
      #next IPS_LINE if !$allowed_samples{$ips_line->name};
      next IPS_LINE if $ips_line->name !~ /HPSI/;
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;
      if ($reprogramming_tech =~ /cytotune/) {
        $reprogramming_tech = 'sendai';
      }

      #if (scalar grep { $ips_line->name =~ m/$_$/ } @feeder_free_temp_override) {
        #$growing_conditions = 'E8';
      #}

      my %output = (name => $ips_line->name,
          cell_type => 'iPSC',
          derived_from => $tissue->name,
          donor => $donor_name,
          biosample_id => $ips_line->biosample_id,
          tissue_biosample_id => $tissue->biosample_id,
          donor_biosample_id => $donor->biosample_id,
          derived_from_cell_type => $tissue->type,
          reprogramming => $reprogramming_tech,
          gender => $donor->gender,
          age => $donor->age,
          disease => $donor->disease,
          ethnicity => $donor->ethnicity,
          growing_conditions_gtarray => $ips_line->growing_conditions_qc1,
          growing_conditions_gexarray => $ips_line->growing_conditions_qc1,
          growing_conditions_mtarray => $ips_line->growing_conditions_qc2,
          growing_conditions_rnaseq => $ips_line->growing_conditions_qc2,
          growing_conditions_exomeseq => $ips_line->growing_conditions_qc2,
          growing_conditions_proteomics => $ips_line->growing_conditions_qc2,
          cnv_num_different_regions => $cnv_details{$ips_line->name}->[1],
          cnv_length_different_regions_Mbp => $cnv_details{$ips_line->name}->[2],
          cnv_length_shared_differences_Mbp => $cnv_details{$ips_line->name}->[3],
          pluri_raw => $pluritest_details{$ips_line->name}->[1],
          pluri_logit_p => $pluritest_details{$ips_line->name}->[2],
          pluri_novelty => $pluritest_details{$ips_line->name}->[3],
          pluri_novelty_logit_p => $pluritest_details{$ips_line->name}->[4],
          pluri_rmsd => $pluritest_details{$ips_line->name}->[5],
          'rnaseq.sendai_reads' => $rna_sendai_reads{$ips_line->name},
      );
      if (my $ips_ag_lims_fields = $ag_lims_fields{$ips_line->name}) {
        foreach my $output_field (@ag_lims_output_fields) {
          if (my $field_val = $ips_ag_lims_fields->{$output_field}) {
            $output{$output_field} = $field_val eq 'NA' ? '' : $field_val;
          }
        }
      };
      my (@sort_parts) = $ips_line->name =~ /\w+(\d\d)(\d\d)\w*-([a-z]+)_(\d+)/;
      push(@output_lines, [\@sort_parts, join("\t", map {$_ // ''} @output{@output_fields, @ag_lims_output_fields})]);
      $tissue_has_data = 1;

    }
    next TISSUE if !$tissue_has_data;
    my %output = (name => $tissue->name,
        cell_type => $tissue->type,
        biosample_id => $tissue->biosample_id,
        donor_biosample_id => $donor->biosample_id,
        gender => $donor->gender,
        age => $donor->age,
        disease => $donor->disease,
        ethnicity => $donor->ethnicity,
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
