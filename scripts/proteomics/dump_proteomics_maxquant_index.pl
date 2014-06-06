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
my $type = 'PROT_TXT';
my $raw_index = '/nfs/research2/hipsci/drop/hip-drop/tracked/proteomics/raw_data/proteomics.raw_data.index';

&GetOptions(
  'dbhost=s'       => \$dbhost,
  'dbname=s'       => \$dbname,
  'dbuser=s'       => \$dbuser,
  'dbpass=s'       => \$dbpass,
  'dbport=s'       => \$dbport,
  'type=s'       => \$type,
  'raw_index=s'       => \$raw_index,
   );

my %raw_cell_lines;
open my $RAW, '<', $raw_index or die "could not open $raw_index $!";
<$RAW>;
LINE:
while (my $line = <$RAW>) {
  my ($cell_line, $raw_id) = split("\t", $line);
  $raw_cell_lines{$raw_id} = $cell_line;
}
close $RAW;

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
    -host   => $dbhost,
    -user   => $dbuser,
    -port   => $dbport,
    -dbname => $dbname,
    -pass   => $dbpass,
);
my $fa = $db->get_FileAdaptor;
my %index_data;
FILE:
foreach my $file (@{$fa->fetch_by_type($type)}) {
  my $path = $file->name;
  my ($filename, $dir) = fileparse($path);
  next FILE if $dir !~ m{/maxquant/};
  my ($basename, $filetype) = $filename =~ /^(.*)\.([^.]*)\.txt$/;
  next FILE if lc($filetype) ne 'summary';
  my ($cell_line) = $dir =~ /(HPSI\d+i-\w+)/;
  open my $IN, '<', $path or die "could not open $path $!";
  <$IN>;
  my %raw_ids;
  LINE:
  while (my $line = <$IN>) {
    my ($raw_id) = $line =~ /^(PTSS\d+)/;
    next LINE if !$raw_id;
    $raw_ids{$raw_id} = 1;
  }
  close $IN;
  my %exp_cell_lines;
  foreach my $raw_id (keys %raw_ids) {
    my $exp_cell_line = $raw_cell_lines{$raw_id};
    die "error $raw_id in $path" if !$exp_cell_line;
    $exp_cell_lines{$exp_cell_line} += 1;
  }
  my @refs = grep {$_ ne $cell_line} keys %exp_cell_lines;;
  die "too many refs $path" if @refs >1;
  my $ref = scalar @refs ? $refs[0] : '-';
  my $num_repeats = $exp_cell_lines{$cell_line};
  die "no data for $cell_line in $path" if !$num_repeats;
  $index_data{$basename} = [$cell_line, $basename, $ref, $num_repeats];
}


print '#', join("\t", qw(cell_line basename reference_cell_line num_repeats)), "\n";
foreach my $basename (sort {$a cmp $b} keys %index_data) {
  print join("\t", @{$index_data{$basename}}), "\n";
}
