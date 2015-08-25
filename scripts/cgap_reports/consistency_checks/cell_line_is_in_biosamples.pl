#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

my ($main_hipsci_group_id) = @ARGV;
my $main_hipsci_group = BioSD::fetch_group($main_hipsci_group_id);
my ($update_date) = @{$main_hipsci_group->property('Submission Update Date')->values()};

my $ips_lines = read_cgap_report(date_iso=>$update_date, days_old=>8)->{ips_lines};

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  my $ips_id = $ips_line->biosample_id;
  if (! $ips_id) {
    if ($ips_line->name =~ /^HPSI/) {
      printf "%s does not have BioSample ID\n", $ips_line->name;
    }
    next IPS_LINE;
  }
  my $biosd_ips_line = BioSD::fetch_sample($ips_id);
  if (! $biosd_ips_line) {
    printf "%s does not exist in BioSamples\n", $ips_id;
  }

  my $tissue = $ips_line->tissue;
  if (! $tissue) {
      printf "%s is not derived from a tissue\n", $ips_line->name;
      next IPS_LINE;
  }
  my $tissue_id = $tissue->biosample_id;
  if (! $tissue_id) {
    printf "%s does not have BioSample ID\n", $tissue->name;
    next IPS_LINE;
  }
  my $biosd_tissue = BioSD::fetch_sample($tissue_id);
  if (! $biosd_tissue) {
    printf "%s does not exist in BioSamples\n", $tissue_id;
  }


  my $donor = $tissue->donor;
  if (! $donor) {
      printf "%s is not derived from a donor\n", $tissue->name;
      next IPS_LINE;
  }
  my $donor_id = $donor->biosample_id;
  if (! $donor_id) {
    printf "%s does not have BioSample ID\n", $donor->name;
    next IPS_LINE;
  }
  my $biosd_donor = BioSD::fetch_sample($donor_id);
  if (! $biosd_donor) {
    printf "%s does not exist in BioSamples\n", $donor_id;
  }
}



