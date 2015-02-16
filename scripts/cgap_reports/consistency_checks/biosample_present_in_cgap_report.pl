#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

my ($hipsci_group_id) = @ARGV;

my %allowed_ids;

my $hipsci_group = BioSD::fetch_group($hipsci_group_id);
my ($update_date) = @{$hipsci_group->property('Submission Update Date')->values()};

my ($ips_lines, $tissues, $donors) = @{read_cgap_report(date_iso=>$update_date)}{qw(ips_lines tissues donors)};

SAMPLE:
foreach my $sample (@$ips_lines, @$tissues, @$donors) {
  next SAMPLE if ! $sample->biosample_id;
  $allowed_ids{$sample->biosample_id} = 1;
}


my %biosamples_in_group;
foreach my $biosample (@{$hipsci_group->samples}) {
  $biosamples_in_group{$biosample->id} = 1;
  if (! $allowed_ids{$biosample->id}) {
    printf "%s is not in CGaP report\n", $biosample->id;
  }
}

foreach my $allowed_id (keys %allowed_ids) {
    if (! $biosamples_in_group{$allowed_id}) {
      printf "%s is in CGaP report but not in HipSci group\n", $allowed_id;
    }
}
