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
&GetOptions(
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
);

die "did not get a demographic file on the command line" if !$demographic_filename;

my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>7)}{qw(donors tissues ips_lines)};
$donors = improve_donors(donors=>$donors, demographic_file=>$demographic_filename);
$tissues = improve_tissues(tissues=>$tissues);
$ips_lines = improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file =>$growing_conditions_filename);


my @output_fields = qw( name cell_type derived_from biosample_id tissue_biosample_id
    donor_biosample_id derived_from_cell_type reprogramming gender age disease
    ethnicity growing_conditions selected_for_genomics);
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
      #next IPS_LINE if !$ips_line->qc1;
      next IPS_LINE if $ips_line->name !~ /HPSI/;
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;

      my $selected_for_genomics = $ips_line->selected_for_genomics // '';
      $selected_for_genomics =~ s/\s.*//;

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
          selected_for_genomics => $selected_for_genomics,
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
print map {$_->[1], "\n"} sort {$a->[0][1] <=> $b->[0][1]
                            || $a->[0][0] <=> $b->[0][0]
                            || $a->[0][2] cmp $b->[0][2]
                            || $a->[0][3] <=> $b->[0][3]} @output_lines;
