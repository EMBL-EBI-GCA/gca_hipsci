#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_ips_lines);
use BioSD;
use Text::Delimited;

my $file = $ARGV[0] || die "did not get a file on the command line";

my $ips_lines = read_cgap_report()->{ips_lines};
improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file=>$file);
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

my %is_feeder_free;

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  next IPS_LINE if !$ips_line->biosample_id;
  my $growing_conditions = $ips_line->growing_conditions;
  next IPS_LINE if !$growing_conditions;

  my $biosample = BioSD::Sample->new($ips_line->biosample_id);
  next IPS_LINE if !$biosample->is_valid;

  $growing_conditions =~ s/^feeder$/on feeder cells/;
  my $biosd_growing_conditions = $biosample->property('growing conditions');
  if (!$biosd_growing_conditions) {
    print join("\t", $biosample->id, 'comment[growing conditions]', $growing_conditions, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
  }
  elsif ($biosd_growing_conditions && $biosd_growing_conditions->values->[0] ne $growing_conditions) {
    print join(' ', 'mismatching', $growing_conditions, $biosd_growing_conditions->values->[0]), "\n";
  }
}
