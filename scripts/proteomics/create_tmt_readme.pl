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

=pod

=head1 NAME

$GCA_HIPSCI/scripts/proteomics/create_tmt_readme.pl

=head1 SYNOPSIS

This script is for producing the readme files that accompany Dundee's TMT maxquant data

The output readme file states which cell lines were used in the analysis. The output file should accompany the data files when they get put into the tracked area of the private FTP site.

=head1 REQUIREMENTS

Make sure you are using a recent export from Dundee's peptracker. Download a new version from: https://peptracker.com/dm/projects/1102/json

The default file path for the exported json is: /nfs/research2/hipsci/tracking_resources/dundee_peptracker/peptracker.json. This should be a soft link to the newest version

You also need a experimentalDesignTemplate.txt file. This is one of the many files that is sent in by Dundee with the maxquant data.

=head1 OPTIONS

-json: file path of peptracker json file, default is /nfs/research2/hipsci/tracking_resources/dundee_peptracker/peptracker.json

-exp_design: file path of the experimentalDesignTemplate.txt file received from Dundee

=head1 Example

perl create_tmt_readme.pl -exp_design ./data/experimentalDesignTemplate.txt > README.proteomics.maxquant.xxxx.TMT_batch_xx.2017xxxx

=cut
