#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_ips_lines);
use BioSD;
use Text::Delimited;

my @feeder_free_temp_override = (
  qw(leeh_3 iakz_1 febc_2 nibo_3 aehn_2 oarz_22 zisa_33 peop_4 dard_2 coxy_33 xisg_33 oomz_22 dovq_33 liun_22 xavk_33 aehn_22 funy_1 funy_3 giuf_1 giuf_3 iill_1 iill_3 bima_1 bima_2 ieki_2 ieki_3 qolg_1 qolg_3 bulb_1 gusc_1 gusc_2 gusc_3)
);

my $file = $ARGV[0] || die "did not get a file on the command line";

my $ips_lines = read_cgap_report()->{ips_lines};
improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file=>$file);
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

my %is_feeder_free;

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  next IPS_LINE if !$ips_line->biosample_id;
  my $growing_conditions = $ips_line->growing_conditions;
  if (scalar grep { $ips_line->name =~ m/$_$/ } @feeder_free_temp_override) {
    $growing_conditions = 'E8';
  }
  next IPS_LINE if !$growing_conditions;

  my $biosample = BioSD::Sample->new($ips_line->biosample_id);
  next IPS_LINE if !$biosample->is_valid;

  $growing_conditions =~ s/^feeder$/on feeder cells/;

  if ($growing_conditions eq 'transferred') {
    my $transfer_date = $ips_line->transfer_to_feeder_free;
    $transfer_date =~ s/ .*//;
    $growing_conditions = "grown on feeder cells until $transfer_date and is now maintained in E8 media";
  }
  my $biosd_growing_conditions = $biosample->property('growing conditions');
  if (!$biosd_growing_conditions) {
    print join("\t", $biosample->id, 'comment[growing conditions]', $growing_conditions, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
  }
  elsif ($biosd_growing_conditions && $biosd_growing_conditions->values->[0] ne $growing_conditions) {
    print join(' ', 'mismatching', $growing_conditions, $biosd_growing_conditions->values->[0]), "\n";
  }
}
