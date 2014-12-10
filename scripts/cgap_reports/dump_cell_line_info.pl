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


my @output_fields = qw( name derived_from biosample_id tissue_biosample_id
    donor_biosample_id derived_from_cell_type reprogramming gender age disease
    ethnicity growing_conditions);
print join("\t", @output_fields), "\n";

my @output_lines;
DONOR:
foreach my $donor (@$donors) {
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {

    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      next IPS_LINE if !$ips_line->biosample_id;
      next IPS_LINE if !$ips_line->qc1;
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;

      my %output = (name => $ips_line->name, derived_from => $tissue->name,
          biosample_id => $ips_line->biosample_id,
          tissue_biosample_id => $tissue->biosample_id,
          donor_biosample_id => $donor->biosample_id,
          derived_from_cell_type => $tissue->type,
          reprogramming => $reprogramming_tech,
          gender => $donor->gender,
          age => $donor->age,
          disease => $donor->disease,
          ethnicity => $donor->ethnicity,
          growing_conditions => $ips_line->growing_conditions,
      );
      push(@output_lines, [$ips_line->biosample_id, join("\t", map {$_ // ''} @output{@output_fields})]);

    }
  }
}
print map {$_->[1], "\n"} sort {$a->[0] cmp $b->[0]} @output_lines;
