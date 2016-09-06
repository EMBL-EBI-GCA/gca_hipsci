use warnings;

use Getopt::Long;
use File::Find;

my ($bamlocaldir, $wigoutputdir, $reference, $flags, $bamToBwpath);
my $threads = 4;

GetOptions(
  "bamlocaldir=s" => \$bamlocaldir,
  "wigoutputdir=s" => \$wigoutputdir,
  "reference=s" => \$reference,
  "threads=s" => \$threads,
  "flags=s" => \$flags,
  "bamToBwpath=s" => \$bamToBwpath,
);

die "Missing parameters" if !$bamlocaldir || !$wigoutputdir || !$reference || !$threads || !$flags || !$bamToBwpath;

my @bamfiles;
find(\&wanted, $bamlocaldir);
sub wanted {push(@bamfiles, $File::Find::name)};

foreach my $file (@bamfiles){
  if ($file =~ /.bam$/){
    #TODO Submit all of these to LSF
    print "perl $bamToBwpath -b $file -o $wigoutputdir -r $reference -threads $threads -flags $flags", "\n";
  }
}