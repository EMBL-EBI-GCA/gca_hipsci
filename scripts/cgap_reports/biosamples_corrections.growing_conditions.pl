#!/usr/bin/env perl

use strict;
use warnings;

use HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;
use Text::Delimited;

my $file = $ARGV[0] || die "did not get a file on the command line";

my $ips_lines = read_cgap_report()->{ips_lines};
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

my %is_feeder_free;
my $feeder_file = new Text::Delimited;
$feeder_file->delimiter(";");
$feeder_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $feeder_file->read) {
  next LINE if !$line_data->{sample} || !$line_data->{is_feeder_free};
  $is_feeder_free{$line_data->{sample}} = $line_data->{is_feeder_free};
}

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  next IPS_LINE if !$ips_line->biosample_id;
  my ($uuid) = $ips_line->uuid;
  next IPS_LINE if !$is_feeder_free{$uuid};

  my $biosample = BioSD::Sample->new($ips_line->biosample_id);
  next IPS_LINE if !$biosample->is_valid;

  my $growing_conditions = $is_feeder_free{$uuid} eq 'Y' ? 'E8'
                        : $is_feeder_free{$uuid} eq 'N' ? 'on feeder cells'
                        : undef;
  my $biosd_growing_conditions = $biosample->property('growing conditions');
  if (!$biosd_growing_conditions) {
    print join("\t", $biosample->id, 'comment[growing conditions]', $growing_conditions, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
  }
  elsif ($biosd_growing_conditions && $biosd_growing_conditions->values->[0] ne $growing_conditions) {
    print join(' ', 'mismatching', $growing_conditions, $biosd_growing_conditions->values->[0]), "\n";
  }
}
$feeder_file->close;
