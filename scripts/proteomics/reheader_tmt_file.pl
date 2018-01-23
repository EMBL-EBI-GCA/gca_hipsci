#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use JSON qw();
use ReseqTrack::Tools::HipSci::Peptracker qw(exp_design_to_pep_ids pep_id_to_tmt_lines);

my $peptracker_json = '/nfs/research1/hipsci/tracking_resources/dundee_peptracker/peptracker.json';
my ($exp_design);

&GetOptions(
  'json=s'       => \$peptracker_json,
  'exp_design=s'       => \$exp_design,
   );


open my $fh, '<', $peptracker_json or die $!;
my $peptracker_obj = JSON::decode_json(<$fh>);
close $fh;

my $header = <STDIN>;
$header =~ s/\R//;
foreach my $pep_id (@{exp_design_to_pep_ids($exp_design)}) {
  my $cell_lines = pep_id_to_tmt_lines($pep_id, $peptracker_obj);
  while (my ($index, $cell_line) = each @$cell_lines) {
    $header =~ s/\b$index $pep_id/$cell_line $pep_id/g;
  }
}
print $header, "\n";
while (my $line = <STDIN>) {
  $line =~ s/\R//;
  print $line, "\n";
}

=pod

=head1 NAME

$GCA_HIPSCI/scripts/proteomics/reheader_tmt_file.pl

=head1 SYNOPSIS

TMT maxquant files received by Dundee do not contain cell line names in the first line of the file.

For example a column header in one of the data files might be: Reporter intensity corrected 3 PT6383

A more helpful column header for downstream users is: Reporter intensity corrected HPSI0214i-poih_2 PT6383

This script re-writes the maxquant data files and fixes the column headers

=head1 REQUIREMENTS

Make sure you are using a recent export from Dundee's peptracker. Download a new version from: https://peptracker.com/dm/projects/1102/json

The default file path for the exported json is: /nfs/research1/hipsci/tracking_resources/dundee_peptracker/peptracker.json. This should be a soft link to the newest version

You also need a experimentalDesignTemplate.txt file. This is one of the many files that is sent in by Dundee with the maxquant data.

=head1 OPTIONS

-json: file path of peptracker json file, default is /nfs/research1/hipsci/tracking_resources/dundee_peptracker/peptracker.json

-exp_design: file path of the experimentalDesignTemplate.txt file received from Dundee

=head1 Example

Note the data file is read on STDIN and written on STDOUT:

perl create_tmt_readme.pl -exp_design ./data/experimentalDesignTemplate.txt
  < ./incoming/peptides.txt > ./fixed/hipsci.proteomics.maxquant.xxx.TMT_batch_xx.2017xxxx.peptides.txt

=cut
