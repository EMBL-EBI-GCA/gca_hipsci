#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
my $res = LWP::UserAgent->new->get('ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2016/06/PXD003903/hipsci.proteomics.pilot_sample_index.20160331.tsv');
die $res->status_line if !$res->is_success;
print $res->decoded_content;
