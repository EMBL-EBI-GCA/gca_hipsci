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

my @feeder_free_temp_override = (
  qw(leeh_3 iakz_1 febc_2 nibo_3 aehn_2 oarz_22 zisa_33 peop_4 dard_2 coxy_33 xisg_33 oomz_22 dovq_33 liun_22 xavk_33 aehn_22 funy_1 funy_3 giuf_1 giuf_3 iill_1 iill_3 bima_1 bima_2 ieki_2 ieki_3 qolg_1 qolg_3 bulb_1 gusc_1 gusc_2 gusc_3)
);

my $demographic_filename;
my $growing_conditions_filename;
my $cnv_filename;
my $pluritest_filename;
my $qc1_allowed_samples_filename;
&GetOptions(
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
  'pluritest_file=s' => \$pluritest_filename,
  'cnv_filename=s' => \$cnv_filename,
  'qc1_allowed_samples_filename=s' => \$qc1_allowed_samples_filename,
);

die "did not get a demographic file on the command line" if !$demographic_filename;

my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>7)}{qw(donors tissues ips_lines)};
$donors = improve_donors(donors=>$donors, demographic_file=>$demographic_filename);
$tissues = improve_tissues(tissues=>$tissues);
$ips_lines = improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file =>$growing_conditions_filename);

my %allowed_samples;
open my $qc1_fh, '<', $qc1_allowed_samples_filename or die "could not open $cnv_filename $!";
<$qc1_fh>;
while (my $line = <$qc1_fh>) {
  chomp $line;
  $allowed_samples{$line} = 1;
}
close $qc1_fh;

my %cnv_details;
open my $cnv_fh, '<', $cnv_filename or die "could not open $cnv_filename $!";
<$cnv_fh>;
while (my $line = <$cnv_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $cnv_details{$split_line[0]} = \@split_line;
}
close $cnv_fh;

my %pluritest_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $pluritest_details{$split_line[0]} = \@split_line;
}
close $pluri_fh;

my @output_fields = qw( name cell_type derived_from biosample_id tissue_biosample_id
    donor_biosample_id derived_from_cell_type reprogramming gender age disease
    ethnicity growing_conditions
    cnv_num_different_regions cnv_length_different_regions_Mbp cnv_length_shared_differences_Mbp
    pluri_raw pluri_logit_p pluri_novelty pluri_novelty_logit_p pluri_rmsd);
print join("\t", @output_fields), "\n";

my @output_lines;
DONOR:
foreach my $donor (@$donors) {
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

      my $growing_conditions = $ips_line->growing_conditions;
      if (scalar grep { $ips_line->name =~ m/$_$/ } @feeder_free_temp_override) {
        $growing_conditions = 'E8';
      }

      my %output = (name => $ips_line->name,
          cell_type => 'iPSC',
          derived_from => $tissue->name,
          biosample_id => $ips_line->biosample_id,
          tissue_biosample_id => $tissue->biosample_id,
          donor_biosample_id => $donor->biosample_id,
          derived_from_cell_type => $tissue->type,
          reprogramming => $reprogramming_tech,
          gender => $donor->gender,
          age => $donor->age,
          disease => $donor->disease,
          ethnicity => $donor->ethnicity,
          growing_conditions => $growing_conditions,
          cnv_num_different_regions => $cnv_details{$ips_line->name}->[1],
          cnv_length_different_regions_Mbp => $cnv_details{$ips_line->name}->[2],
          cnv_length_shared_differences_Mbp => $cnv_details{$ips_line->name}->[3],
          pluri_raw => $pluritest_details{$ips_line->name}->[1],
          pluri_logit_p => $pluritest_details{$ips_line->name}->[2],
          pluri_novelty => $pluritest_details{$ips_line->name}->[3],
          pluri_novelty_logit_p => $pluritest_details{$ips_line->name}->[4],
          pluri_rmsd => $pluritest_details{$ips_line->name}->[5],
      );
      my (@sort_parts) = $ips_line->name =~ /\w+(\d\d)(\d\d)\w*-([a-z]+)_(\d+)/;
      push(@output_lines, [\@sort_parts, join("\t", map {$_ // ''} @output{@output_fields})]);
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
    );
    my (@sort_parts) = $tissue->name =~ /\w+(\d\d)(\d\d)\w*-([a-z]+)/;
    push(@sort_parts, 0);
    push(@output_lines, [\@sort_parts, join("\t", map {$_ // ''} @output{@output_fields})]);
  }
}
print map {$_->[1], "\n"} sort {
                               $a->[0][1] <=> $b->[0][1]
                            || $a->[0][0] <=> $b->[0][0]
                            || $a->[0][2] cmp $b->[0][2]
                            || $a->[0][3] <=> $b->[0][3]
                                } @output_lines;
