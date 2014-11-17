#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);

my ($ips_lines) = @{read_cgap_report()}{ips_lines};

print join("\t", 'cell_line', 'release_to_kcl', 'releace_to_dundee'), "\n";
SAMPLE:
foreach my $sample (@$ips_lines) {
  my $kings_date = $sample->release_to_kcl;
  my $dundee_date = $sample->release_to_dundee;
  next SAMPLE if !$kings_date && !$dundee_date;
  print join("\t", $sample->name, $kings_date || '-', $dundee_date || '-'), "\n";
}
