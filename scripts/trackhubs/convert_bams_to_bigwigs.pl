#!/usr/bin/env perl

use strict;
use warnings;

#Requires threaded perl environment "perlbrew use perl-5.16.3_RH7_threaded;source ~/.pcap_bashrc"

use Getopt::Long;
use File::Find;
use ReseqTrack::Tools::BatchSubmission::LSF;

my ($bamlocaldir, $wigoutputdir, $reference, $flags, $bamToBwpath, $farmlogfolder, $threadedperlbrew);
my $threads = 4;

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "wigoutputdir=s" => \$wigoutputdir,
  "reference=s" => \$reference,
  "threads=s" => \$threads,
  "flags=s" => \$flags,
  "bamToBwpath=s" => \$bamToBwpath,
  "farmlogfolder=s" => \$farmlogfolder,
);

die "Missing parameters" if !$bamlocaldir || !$wigoutputdir || !$reference || !$threads || !$flags || !$bamToBwpath || !$farmlogfolder;

my @bamfiles;
find(\&wanted, $bamlocaldir);
sub wanted {push(@bamfiles, $File::Find::name)};

my $lsf = ReseqTrack::Tools::BatchSubmission::LSF->new(
  -program => "bsub",
  -max_job_number => 10000,
  -sleep => 360,
);
#system "perlbrew use $threadedperlbrew";
foreach my $file (@bamfiles){
  if ($file =~ /.bam$/){
    my $sample = "bam2bw-".(split(/\./, (split(/\//, $file))[-1]))[0];
    my $farmlogfile = $farmlogfolder."/".$sample.".log";
    my $wigoutputdir = $wigoutputdir."/".$sample."/";
    my $cmd_to_run = "perl $bamToBwpath -b $file -o $wigoutputdir -r $reference -threads $threads -f $flags";
    my $bsub_cmd = $lsf->construct_command_line($cmd_to_run, "-q production-rh7", $farmlogfile, $sample, 0);
    my $result = `$bsub_cmd 2>&1`;
    print $result, "\n";
  }
}