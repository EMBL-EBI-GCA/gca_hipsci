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

$|=1;
my $header = <STDIN>;
foreach my $pep_id (@{exp_design_to_pep_ids($exp_design)}) {
  my $cell_lines = pep_id_to_tmt_lines($pep_id, $peptracker_obj);
  while (my ($index, $cell_line) = each @$cell_lines) {
    $header =~ s/\b$index $pep_id/$cell_line $pep_id/g;
  }
}
print $header;
print <STDIN>;
