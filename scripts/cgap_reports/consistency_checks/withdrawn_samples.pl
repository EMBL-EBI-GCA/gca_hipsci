#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

my $days_old = 1;

my $today_hash = read_cgap_report();
my $old_hash = read_cgap_report(days_old=>$days_old);

my %today_donor_id;
DONOR:
foreach my $today_donor (@{$today_hash->{donors}}) {
  next DONOR if !$today_donor->biosample_id;
  $today_donor_id{$today_donor->biosample_id} = 1;
}

DONOR:
foreach my $old_donor (@{$old_hash->{donors}}) {
  next DONOR if !$old_donor->biosample_id;
  if (!$today_donor_id{$old_donor->biosample_id}) {
    printf "Donor %s has been removed from cgap report in the last %i days\n", $old_donor->biosample_id, $days_old;
  }
}



my %today_tissue_id;
TISSUE:
foreach my $today_tissue (@{$today_hash->{tissues}}) {
  next TISSUE if !$today_tissue->biosample_id;
  $today_tissue_id{$today_tissue->biosample_id} = 1;
}

TISSUE:
foreach my $old_tissue (@{$old_hash->{tissues}}) {
  next TISSUE if !$old_tissue->biosample_id;
  if (!$today_tissue_id{$old_tissue->biosample_id}) {
    printf "Tissue %s has been removed from cgap report in the last %i days\n", $old_tissue->biosample_id, $days_old;
  }
}



my %today_ips_line_id;
IPS_LINE:
foreach my $today_ips_line (@{$today_hash->{ips_lines}}) {
  next IPS_LINE if !$today_ips_line->biosample_id;
  $today_ips_line_id{$today_ips_line->biosample_id} = 1;
}

IPS_LINE:
foreach my $old_ips_line (@{$old_hash->{ips_lines}}) {
  next IPS_LINE if !$old_ips_line->biosample_id;
  if (!$today_ips_line_id{$old_ips_line->biosample_id}) {
    printf "IPS line %s has been removed from cgap report in the last %i days\n", $old_ips_line->biosample_id, $days_old;
  }
}



my %today_sequencescape_id;
foreach my $today_ips_line (@{$today_hash->{ips_lines}}) {
  foreach my $sequencescape (@{$today_ips_line->sequencescape}) {
    $today_sequencescape_id{$sequencescape->internal_id} = 1;
  }
}

foreach my $old_ips_line (@{$old_hash->{ips_lines}}) {
  foreach my $old_sequencescape (@{$old_ips_line->sequencescape}) {
    if (!$today_sequencescape_id{$old_sequencescape->internal_id}) {
      printf "IPS line %s has sequencescape object removed from cgap report in the last %i days\n", $old_ips_line->biosample_id, $days_old;
    }
  }
}

