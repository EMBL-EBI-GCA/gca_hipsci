#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

my $days_old = 28;

my $today_hash = read_cgap_report();
my $old_hash = read_cgap_report(days_old=>$days_old);

my $num_today_donors = scalar grep {$_->biosample_id} @{$today_hash->{donors}};
my $num_old_donors = scalar grep {$_->biosample_id} @{$old_hash->{donors}};
if ($num_old_donors >= $num_today_donors) {
  printf "Number of donors has changed from %i to %i in %i days\n", $num_old_donors, $num_today_donors, $days_old;
}

my $num_today_tissues = scalar grep {$_->biosample_id} @{$today_hash->{tissues}};
my $num_old_tissues = scalar grep {$_->biosample_id} @{$old_hash->{tissues}};
if ($num_old_tissues >= $num_today_tissues) {
  printf "Number of tissues has changed from %i to %i in %i days\n", $num_old_tissues, $num_today_tissues, $days_old;
}

my $num_today_ips_lines = scalar grep {$_->biosample_id} @{$today_hash->{ips_lines}};
my $num_old_ips_lines = scalar grep {$_->biosample_id} @{$old_hash->{ips_lines}};
if ($num_old_ips_lines >= $num_today_ips_lines) {
  printf "Number of ips_lines has changed from %i to %i in %i days\n", $num_old_ips_lines, $num_today_ips_lines, $days_old;
}

