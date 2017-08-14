#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use JSON;
use Try::Tiny;
use autodie;
use Data::Dumper;

my $jsonoutfile;

GetOptions("jsonoutfile=s" => \$jsonoutfile);

die "missing json jsonoutfile" if !$jsonoutfile;

my %cellLines;

my $jsonout = encode_json(\%cellLines);
open my $fho, '>', $jsonoutfile or die "could not open $jsonoutfile $!";
print $fho $jsonout;
close($fho);