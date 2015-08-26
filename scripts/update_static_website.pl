#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::StaticWebsite;

my $website_tool = ReseqTrack::Tools::HipSci::StaticWebsite->new(
  git_directory => '/nfs/production/reseq-info/work/streeter/hipsci/gca_hipsci_website/',
  rsync_host => 'ebi-004',
  rsync_path =>  '/nfs/production/reseq-info/work/streeter/sandbox/rsync_test',
);

$website_tool->run();
