#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use JSON qw();
use ReseqTrack::Tools::HipSci::Peptracker qw(exp_design_to_pep_ids pep_id_to_tmt_lines);

my $peptracker_json = '/nfs/research2/hipsci/tracking_resources/dundee_peptracker/peptracker.json';
my ($exp_design);

&GetOptions(
  'json=s'       => \$peptracker_json,
  'exp_design=s'       => \$exp_design,
   );


open my $fh, '<', $peptracker_json or die $!;
my $peptracker_obj = JSON::decode_json(<$fh>);
close $fh;

my $pep_ids = exp_design_to_pep_ids($exp_design);

printf "This experiment contains %i fractionations: %s\n", scalar @$pep_ids, join(' ', @$pep_ids);
print "Each fractionation is a mixture of TMT labelled cell lines. This file lists the cell lines used in each fractionation of the experiment.\n";

foreach my $pep_id (@$pep_ids) {
  print "\n\n$pep_id\n";
  my $lines = pep_id_to_tmt_lines($pep_id, $peptracker_obj);
  while (my ($index, $line) = each @$lines) {
    print $index, "\t", $line, "\n";
  }
}
