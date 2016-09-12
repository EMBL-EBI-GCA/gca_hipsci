#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use File::Find;

my ($wigdir, $stagingdir);

GetOptions(
  "wigdir=s" => \$wigdir,
  "stagingdir=s" => \$stagingdir,
);

die "Missing local directory containing BigWig files -wigdir" if !$wigdir;
die "Missing directory to collate BigWig files into -stagingdir" if !$stagingdir;


my @wigfiles;
find(\&wanted, $wigdir);
sub wanted {push(@wigfiles, $File::Find::name)};

foreach my $file (@wigfiles){
  if ($file =~ /.bw$/){
    my $filename = (split(/\//, $file))[-1];
    my $outfile = $stagingdir."/".$filename;
    print "cp $file $outfile\n";
    my $result = `cp $file $outfile`;
    print $result, "\n";
  }
}
