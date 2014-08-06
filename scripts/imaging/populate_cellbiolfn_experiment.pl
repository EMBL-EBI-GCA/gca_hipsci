#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellomics';
my $dbuser = 'g1krw';
my $dbpass;
my $file;
my $cellline;
&GetOptions(
  'dbhost=s' => \$dbhost,
  'dbport=s' => \$dbport,
  'dbname=s' => \$dbname,
  'dbuser=s' => \$dbuser,
  'dbpass=s' => \$dbpass,
  'file=s' => \$file,
  'cellline' => \$cellline,
);

die "did not get a file on the command line" if !$file;

my $dbh = DBI->connect(
  "dbi:mysql:dbname=$dbname;host=$dbhost;port=$dbport",
  $dbuser, $dbpass,
) or die $DBI::errstr;

my $sql1 = <<"SQL";
  INSERT INTO experiment (
    cell_line_id, evaluation_guid, p_col, p_row,
    num_nuclei, num_cells,
    cell_nuc_area_mean, cell_nuc_area_sd, cell_nuc_area_sum, cell_nuc_area_max, cell_nuc_area_min, cell_nuc_area_median,
    edu_median_mean, edu_median_sd, edu_median_sum, edu_median_max, edu_median_min, edu_median_median,
    oct_median_mean, oct_median_sd, oct_median_sum, oct_median_max, oct_median_min, oct_median_median,
    inten_nuc_dapi_median_mean, inten_nuc_dapi_median_sd, inten_nuc_dapi_median_sum, inten_nuc_dapi_median_max, inten_nuc_dapi_median_min, inten_nuc_dapi_median_median,
    cells_per_clump_mean, cells_per_clump_sd, cells_per_clump_sum, cells_per_clump_max, cells_per_clump_min, cells_per_clump_median,
    area_mean, area_sd, area_sum, area_max, area_min, area_median,
    roundness_mean, roundness_sd, roundness_sum, roundness_max, roundness_min, roundness_median,
    ratio_w2l_mean, ratio_w2l_sd, ratio_w2l_sum, ratio_w2l_max, ratio_w2l_min, ratio_w2l_median,
    num_singles, compound, concentration, cell_type, cell_count, num_fields
  )
  VALUES (
      (SELECT cell_line_id FROM cell_line WHERE short_name = ?),
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
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
    if ($line =~ m{[Data]}) {
      $have_data = 1;
      next LINE;
    }
  }
  chomp $line;
  my @split_line = split("\t", $line);
  if (!$have_header) {
    foreach my $i (0..$#split_line) {
      $split_line[$i] =~ s/[^\w]//g;
      $field_columns{lc($split_line[$i])} = $i;
    }
    $have_header = 1;
    next LINE;
  }
  foreach my $val (@split_line) {
    undef($val) if $val eq 'Nan';
  }
  $sth1->bind_param(1, $cellline);
  $sth1->bind_param(2, $evaluation_guid);
  $sth1->bind_param(3, $split_line[$field_columns{'column'}]);
  $sth1->bind_param(4, $split_line[$field_columns{'row'}]);
  $sth1->bind_param(5, $split_line[$field_columns{'nucleinumberofobjects'}]);
  $sth1->bind_param(6, $split_line[$field_columns{'cellnumberofobjects'}]);
  $sth1->bind_param(7, $split_line[$field_columns{'cellnucleusareameanperwell'}]);
  $sth1->bind_param(8, $split_line[$field_columns{'cellnucleusareastddevperwell'}]);
  $sth1->bind_param(9, $split_line[$field_columns{'cellnucleusareasumperwell'}]);
  $sth1->bind_param(10, $split_line[$field_columns{'cellnucleusareamaxperwell'}]);
  $sth1->bind_param(11, $split_line[$field_columns{'cellnucleusareaminperwell'}]);
  $sth1->bind_param(12, $split_line[$field_columns{'cellnucleusareamedianperwell'}]);
  $sth1->bind_param(13, $split_line[$field_columns{'celledumedianmeanperwell'}]);
  $sth1->bind_param(14, $split_line[$field_columns{'celledumedianstddevperwell'}]);
  $sth1->bind_param(15, $split_line[$field_columns{'celledumediansumperwell'}]);
  $sth1->bind_param(16, $split_line[$field_columns{'celledumedianmaxperwell'}]);
  $sth1->bind_param(17, $split_line[$field_columns{'celledumedianminperwell'}]);
  $sth1->bind_param(18, $split_line[$field_columns{'celledumedianmedianperwell'}]);
  $sth1->bind_param(19, $split_line[$field_columns{'celloct4mockmedianmeanperwell'}]);
  $sth1->bind_param(20, $split_line[$field_columns{'celloct4mockmedianstddevperwell'}]);
  $sth1->bind_param(21, $split_line[$field_columns{'celloct4mockmediansumperwell'}]);
  $sth1->bind_param(22, $split_line[$field_columns{'celloct4mockmedianmaxperwell'}]);
  $sth1->bind_param(23, $split_line[$field_columns{'celloct4mockmedianminperwell'}]);
  $sth1->bind_param(24, $split_line[$field_columns{'celloct4mockmedianmedianperwell'}]);
  $sth1->bind_param(25, $split_line[$field_columns{'cellintensitynucelusdapimedianmeanperwell'}]);
  $sth1->bind_param(26, $split_line[$field_columns{'cellintensitynucelusdapimedianstddevperwell'}]);
  $sth1->bind_param(27, $split_line[$field_columns{'cellintensitynucelusdapimediansumperwell'}]);
  $sth1->bind_param(28, $split_line[$field_columns{'cellintensitynucelusdapimedianmaxperwell'}]);
  $sth1->bind_param(29, $split_line[$field_columns{'cellintensitynucelusdapimedianminperwell'}]);
  $sth1->bind_param(30, $split_line[$field_columns{'cellintensitynucelusdapimedianmedianperwell'}]);
  $sth1->bind_param(31, $split_line[$field_columns{'cellnumberofcellperclumpsummeanperwell'}]);
  $sth1->bind_param(32, $split_line[$field_columns{'cellnumberofcellperclumpsumstddevperwell'}]);
  $sth1->bind_param(33, $split_line[$field_columns{'cellnumberofcellperclumpsumsumperwell'}]);
  $sth1->bind_param(34, $split_line[$field_columns{'cellnumberofcellperclumpsummaxperwell'}]);
  $sth1->bind_param(35, $split_line[$field_columns{'cellnumberofcellperclumpsumminperwell'}]);
  $sth1->bind_param(36, $split_line[$field_columns{'cellnumberofcellperclumpsummedianperwell'}]);
  $sth1->bind_param(37, $split_line[$field_columns{'cellcellareameanperwell'}]);
  $sth1->bind_param(38, $split_line[$field_columns{'cellcellareastddevperwell'}]);
  $sth1->bind_param(39, $split_line[$field_columns{'cellcellareasumperwell'}]);
  $sth1->bind_param(40, $split_line[$field_columns{'cellcellareamaxperwell'}]);
  $sth1->bind_param(41, $split_line[$field_columns{'cellcellareaminperwell'}]);
  $sth1->bind_param(42, $split_line[$field_columns{'cellcellareamedianperwell'}]);
  $sth1->bind_param(43, $split_line[$field_columns{'cellcellroundnessmeanperwell'}]);
  $sth1->bind_param(44, $split_line[$field_columns{'cellcellroundnessstddevperwell'}]);
  $sth1->bind_param(45, $split_line[$field_columns{'cellcellroundnesssumperwell'}]);
  $sth1->bind_param(46, $split_line[$field_columns{'cellcellroundnessmaxperwell'}]);
  $sth1->bind_param(47, $split_line[$field_columns{'cellcellroundnessminperwell'}]);
  $sth1->bind_param(48, $split_line[$field_columns{'cellcellroundnessmedianperwell'}]);
  $sth1->bind_param(49, $split_line[$field_columns{'cellcellratiowidthtolengthmeanperwell'}]);
  $sth1->bind_param(50, $split_line[$field_columns{'cellcellratiowidthtolengthstddevperwell'}]);
  $sth1->bind_param(51, $split_line[$field_columns{'cellcellratiowidthtolengthsumperwell'}]);
  $sth1->bind_param(52, $split_line[$field_columns{'cellcellratiowidthtolengthmaxperwell'}]);
  $sth1->bind_param(53, $split_line[$field_columns{'cellcellratiowidthtolengthminperwell'}]);
  $sth1->bind_param(54, $split_line[$field_columns{'cellcellratiowidthtolengthmedianperwell'}]);
  $sth1->bind_param(55, $split_line[$field_columns{'singlesnumberofobjects'}]);
  $sth1->bind_param(56, $split_line[$field_columns{'compound'}]);
  $sth1->bind_param(57, $split_line[$field_columns{'concentration'}]);
  $sth1->bind_param(58, $split_line[$field_columns{'celltype'}]);
  $sth1->bind_param(59, $split_line[$field_columns{'cellcount'}]);
  $sth1->bind_param(60, $split_line[$field_columns{'numberofanalyzedfields'}]);
  $sth1->execute;
}
close $IN;
