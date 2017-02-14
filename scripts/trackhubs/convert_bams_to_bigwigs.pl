#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use File::Find;
use ReseqTrack::Tools::BatchSubmission::LSF;

my ($bamlocaldir, $wigoutputdir, $reference, $flags, $bamToBwpath, $farmlogfolder);

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "wigoutputdir=s" => \$wigoutputdir,
  "reference=s" => \$reference,
  "flags=s" => \$flags,
  "bamToBwpath=s" => \$bamToBwpath,
  "farmlogfolder=s" => \$farmlogfolder,
);

die "Missing local directory containing BAMS -bamlocaldir" if !$bamlocaldir;
die "Missing output directory to store BWS -wigoutputdir" if !$wigoutputdir;
die "Missing reference file (e.g. hs37d5.fa) -reference" if !$reference;
die "Missing path to bamToBw script -bamToBwpath" if !$bamToBwpath;
die "Missing directory to store log files -farmlogfolder" if !$farmlogfolder;

my @bamfiles;
find(\&wanted, $bamlocaldir);
sub wanted {push(@bamfiles, $File::Find::name)};

my $lsf = ReseqTrack::Tools::BatchSubmission::LSF->new(
  -program => "bsub",
  -max_job_number => 10000,
  -sleep => 360,
);

foreach my $file (@bamfiles){
  if ($file =~ /.bam$/){
    my $sample = "bam2bw-".(split(/\./, (split(/\//, $file))[-1]))[0];
    my $farmlogfile = $farmlogfolder."/".$sample.".log";
    my $wigoutputdir = $wigoutputdir."/".$sample."/";
    my $wigoutputfile = $wigoutputdir.$sample.".bw";
    if (!-d $wigoutputdir) {
      my @args = ("mkdir", "-m", "775", "$wigoutputdir");
      system(@args) == 0 or die "system @args failed: $?";
    }
    my $cmd_to_run = "$bamToBwpath -i $file -o $wigoutputfile -F $flags -r $reference";
    my $bsub_cmd = $lsf->construct_command_line($cmd_to_run, "-q production-rh7", $farmlogfile, $sample, 0);
    my $result = `$bsub_cmd 2>&1`;
    print $result, "\n";
  }
}