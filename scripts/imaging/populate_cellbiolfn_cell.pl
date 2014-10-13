#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Text::Delimited;
use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellbiolfn';
my $dbuser = 'g1krw';
my $dbpass;
my $file;
&GetOptions(
  'dbhost=s' => \$dbhost,
  'dbport=s' => \$dbport,
  'dbname=s' => \$dbname,
  'dbuser=s' => \$dbuser,
  'dbpass=s' => \$dbpass,
  'file=s' => \$file,
);

die "did not get a file on the command line" if !$file;

my $dbh = DBI->connect(
  "dbi:mysql:dbname=$dbname;host=$dbhost;port=$dbport",
  $dbuser, $dbpass,
) or die $DBI::errstr;

my $sql1 = <<"SQL";
  INSERT INTO cell (
    experiment_id, field, i_cell, i_clump, i_nuc, i_nuc2,
    x_centroid, x_min, x_max,
    y_centroid, y_min, y_max,
    cell_area, nucleus_area, edu_median, oct4_median,
    inten_nuc_dapi_median, roundness, ratio_w2l, clump_size
  )
  VALUES (
      (SELECT experiment_id FROM experiment WHERE p_row = ? AND p_col = ? AND evaluation_guid = ?),
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
  )
SQL
my $sth1 = $dbh->prepare($sql1);

my $evaluation_guid;
my $have_data;
my $have_header;
my %field_columns;
open my $IN, '<', $file or die "could not open $file $!";
LINE:
while (my $line = <$IN>) {
  if (!$have_data) {
    if ($line =~ /Evaluation GUID\s(\S+)/) {
      $evaluation_guid = $1;
    }
    if ($line =~ m{\[Data\]}) {
      $have_data = 1;
    }
    next LINE;
  }
  chomp $line;
  my @split_line = split("\t", $line);
  if (!$have_header) {
    foreach my $i (0..$#split_line) {
      $split_line[$i] =~ s/[^A-Za-z0-9]//g;
      $field_columns{substr(lc($split_line[$i]),0,32)} = $i;
    }
    $have_header = 1;
    next LINE;
  }
  foreach my $val (@split_line) {
    undef($val) if $val eq 'NaN';
  }
  my ($x_min, $y_min, $x_max, $y_max) = $split_line[$field_columns{'boundingbox'}] =~ m{\[(\d+),(\d+),(\d+),(\d+)\]};
  $sth1->bind_param(1, $split_line[$field_columns{'row'}]);
  $sth1->bind_param(2, $split_line[$field_columns{'column'}]);
  $sth1->bind_param(3, $evaluation_guid);
  $sth1->bind_param(4, $split_line[$field_columns{'field'}]);
  $sth1->bind_param(5, $split_line[$field_columns{'objectno'}]);
  $sth1->bind_param(6, $split_line[$field_columns{'cellobjectnoinclumpssingles'}]);
  $sth1->bind_param(7, $split_line[$field_columns{'cellobjectnoinnuclei'}]);
  $sth1->bind_param(8, $split_line[$field_columns{'cellobjectnoinnuclei2'}]);
  $sth1->bind_param(9, $split_line[$field_columns{'x'}]);
  $sth1->bind_param(10, $x_min);
  $sth1->bind_param(11, $x_max);
  $sth1->bind_param(12, $split_line[$field_columns{'y'}]);
  $sth1->bind_param(13, $y_min);
  $sth1->bind_param(14, $y_max);
  $sth1->bind_param(15, $split_line[$field_columns{'cellcellaream2'}]);
  $sth1->bind_param(16, $split_line[$field_columns{'cellnucleusaream'}]);
  $sth1->bind_param(17, $split_line[$field_columns{'celledumedian'}]);
  $sth1->bind_param(18, $split_line[$field_columns{'celloct4median'}]);
  $sth1->bind_param(19, $split_line[$field_columns{'cellintensitynucleusdapimedian'}]);
  $sth1->bind_param(20, $split_line[$field_columns{'cellcellroundness'}]);
  $sth1->bind_param(21, $split_line[$field_columns{'cellcellratiowidthtolength'}]);
  $sth1->bind_param(22, $split_line[$field_columns{'cellnumberofcellperclumpsum'}]);
  $sth1->execute;
}
close $IN;
