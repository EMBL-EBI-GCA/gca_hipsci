#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename qw(fileparse);

use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::File;

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $type = 'PROT_RAW';

&GetOptions(
  'dbhost=s'       => \$dbhost,
  'dbname=s'       => \$dbname,
  'dbuser=s'       => \$dbuser,
  'dbpass=s'       => \$dbpass,
  'dbport=s'       => \$dbport,
  'type=s'       => \$type,
   );

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
    -host   => $dbhost,
    -user   => $dbuser,
    -port   => $dbport,
    -dbname => $dbname,
    -pass   => $dbpass,
);
my $fa = $db->get_FileAdaptor;
my %num_raw;
my %cell_line_raw;
FILE:
foreach my $file (@{$fa->fetch_by_type($type)}) {
  my ($filename, $dir) = fileparse($file->name);
  next FILE if $dir =~ /\/withdrawn\//;
  next FILE if $dir =~ /\/incoming\//;
  next FILE if $dir =~ /\/analysis\//;
  my ($raw_id) = $filename =~ /(^PT[SS]*-?\d+)/;
  die $file->name if !$raw_id;
  $num_raw{$raw_id} +=1;
  if ($num_raw{$raw_id} ==1) {
    my $cell_line = ($dir =~ /HPSI\d+[a-z]*-\w+/) ? $&
                  : ($dir =~ /HPSI_composite_\w+/) ? $&
                  : undef;
    push(@{$cell_line_raw{$cell_line}}, $raw_id);
  }
}


print '#', join("\t", qw(cell_line raw_id fractionation)), "\n";
CELL_LINE:
foreach my $cell_line (sort {$a cmp $b} keys %cell_line_raw) {
  next CELL_LINE if !$cell_line;
  foreach my $raw_id (@{$cell_line_raw{$cell_line}}) {
    my $frac_method = $num_raw{$raw_id} == 16 ? 'SAX'
                    : $num_raw{$raw_id} == 23 ? 'HILIC'
                    : die "Here $raw_id $num_raw{$raw_id}";
    print join("\t", $cell_line, $raw_id, $frac_method), "\n";
  }
}
