#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;
use DateTime::Format::ISO8601;
use DateTime;

my ($hipsci_group_id) = @ARGV;

my $hipsci_group = BioSD::fetch_group($hipsci_group_id);
my ($date) = @{$hipsci_group->property('Submission Update Date')->values()};

my $dt = DateTime::Format::ISO8601->parse_datetime($date);
my $days_since_update = $dt->delta_days(DateTime->now)->days;

if ($days_since_update >= 7) {
  printf "HipSci group was last updated %s days ago: Too long!\n", $days_since_update;
}
