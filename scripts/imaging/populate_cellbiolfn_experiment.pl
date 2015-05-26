#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellbiolfn';
my $dbuser = 'g1krw';
my $dbpass;
my $file;
my $is_production;
&GetOptions(
  'dbhost=s' => \$dbhost,
  'dbport=s' => \$dbport,
  'dbname=s' => \$dbname,
  'dbuser=s' => \$dbuser,
  'dbpass=s' => \$dbpass,
  'file=s' => \$file,
  'is_production!' => \$is_production,
);

die "did not get a file on the command line" if !$file;

if (!defined $is_production) {
  $is_production = $file =~ m{/pipeline_testing_experiments/} ? 0 : 1;
}

my $dbh = DBI->connect(
  "dbi:mysql:dbname=$dbname;host=$dbhost;port=$dbport",
  $dbuser, $dbpass,
) or die $DBI::errstr;

my $sql1 = <<"SQL";
  INSERT INTO experiment (
    cell_line_id, evaluation_guid, p_col, p_row, is_production,
    num_cells,
    nuc_area_mean, nuc_area_sd, nuc_area_sum, nuc_area_max, nuc_area_min, nuc_area_median,
    nuc_roundness_mean, nuc_roundness_sd, nuc_roundness_sum, nuc_roundness_max, nuc_roundness_min, nuc_roundness_median,
    nuc_ratio_w2l_mean, nuc_ratio_w2l_sd, nuc_ratio_w2l_sum, nuc_ratio_w2l_max, nuc_ratio_w2l_min, nuc_ratio_w2l_median,
    edu_median_mean, edu_median_sd, edu_median_sum, edu_median_max, edu_median_min, edu_median_median,
    oct4_median_mean, oct4_median_sd, oct4_median_sum, oct4_median_max, oct4_median_min, oct4_median_median,
    inten_nuc_dapi_median_mean, inten_nuc_dapi_median_sd, inten_nuc_dapi_median_sum, inten_nuc_dapi_median_max, inten_nuc_dapi_median_min, inten_nuc_dapi_median_median,
    cells_per_clump_mean, cells_per_clump_sd, cells_per_clump_sum, cells_per_clump_max, cells_per_clump_min, cells_per_clump_median,
    area_mean, area_sd, area_sum, area_max, area_min, area_median,
    roundness_mean, roundness_sd, roundness_sum, roundness_max, roundness_min, roundness_median,
    ratio_w2l_mean, ratio_w2l_sd, ratio_w2l_sum, ratio_w2l_max, ratio_w2l_min, ratio_w2l_median,
    compound, concentration, cell_count, num_fields
  )
  VALUES (
      (SELECT cell_line_id FROM cell_line WHERE short_name = ? or name = ?),
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
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
      $split_line[$i] =~ s/^cell//i;
      $field_columns{substr(lc($split_line[$i]),0,32)} = $i;
    }
    $have_header = 1;
    next LINE;
  }
  foreach my $val (@split_line) {
    undef($val) if $val eq 'NaN';
  }
  my $short_name = $split_line[$field_columns{'type'}];
  $short_name =~ s/\s/_/g;
  $sth1->bind_param(1, lc($short_name));
  $sth1->bind_param(2, uc($short_name));
  $sth1->bind_param(3, $evaluation_guid);
  $sth1->bind_param(4, $split_line[$field_columns{'column'}]);
  $sth1->bind_param(5, $split_line[$field_columns{'row'}]);
  $sth1->bind_param(6, $is_production);
  $sth1->bind_param(7, $split_line[$field_columns{'numberofobjects'}]);
  $sth1->bind_param(8, $split_line[$field_columns{'nucleusareammeanperwell'}]);
  $sth1->bind_param(9, $split_line[$field_columns{'nucleusareamstddevperwell'}]);
  $sth1->bind_param(10, $split_line[$field_columns{'nucleusareamsumperwell'}]);
  $sth1->bind_param(11, $split_line[$field_columns{'nucleusareammaxperwell'}]);
  $sth1->bind_param(12, $split_line[$field_columns{'nucleusareamminperwell'}]);
  $sth1->bind_param(13, $split_line[$field_columns{'nucleusareammedianperwell'}]);
  $sth1->bind_param(14, $split_line[$field_columns{'nucleusroundnessmeanperwell'}]);
  $sth1->bind_param(15, $split_line[$field_columns{'nucleusroundnessstddevperwell'}]);
  $sth1->bind_param(16, $split_line[$field_columns{'nucleusroundnesssumperwell'}]);
  $sth1->bind_param(17, $split_line[$field_columns{'nucleusroundnessmaxperwell'}]);
  $sth1->bind_param(18, $split_line[$field_columns{'nucleusroundnessminperwell'}]);
  $sth1->bind_param(19, $split_line[$field_columns{'nucleusroundnessmedianperwell'}]);
  $sth1->bind_param(20, $split_line[$field_columns{'nucleusratiowidthtolengthmeanper'}]);
  $sth1->bind_param(21, $split_line[$field_columns{'nucleusratiowidthtolengthstddevp'}]);
  $sth1->bind_param(22, $split_line[$field_columns{'nucleusratiowidthtolengthsumperw'}]);
  $sth1->bind_param(23, $split_line[$field_columns{'nucleusratiowidthtolengthmaxperw'}]);
  $sth1->bind_param(24, $split_line[$field_columns{'nucleusratiowidthtolengthminperw'}]);
  $sth1->bind_param(25, $split_line[$field_columns{'nucleusratiowidthtolengthmedianp'}]);
  $sth1->bind_param(26, $split_line[$field_columns{'edumedianmeanperwell'}]);
  $sth1->bind_param(27, $split_line[$field_columns{'edumedianstddevperwell'}]);
  $sth1->bind_param(28, $split_line[$field_columns{'edumediansumperwell'}]);
  $sth1->bind_param(29, $split_line[$field_columns{'edumedianmaxperwell'}]);
  $sth1->bind_param(30, $split_line[$field_columns{'edumedianminperwell'}]);
  $sth1->bind_param(31, $split_line[$field_columns{'edumedianmedianperwell'}]);
  $sth1->bind_param(32, $split_line[$field_columns{'oct4medianmeanperwell'}]);
  $sth1->bind_param(33, $split_line[$field_columns{'oct4medianstddevperwell'}]);
  $sth1->bind_param(34, $split_line[$field_columns{'oct4mediansumperwell'}]);
  $sth1->bind_param(35, $split_line[$field_columns{'oct4medianmaxperwell'}]);
  $sth1->bind_param(36, $split_line[$field_columns{'oct4medianminperwell'}]);
  $sth1->bind_param(37, $split_line[$field_columns{'oct4medianmedianperwell'}]);
  $sth1->bind_param(38, $split_line[$field_columns{'dapimedianmeanperwell'}]);
  $sth1->bind_param(39, $split_line[$field_columns{'dapimedianstddevperwell'}]);
  $sth1->bind_param(40, $split_line[$field_columns{'dapimediansumperwell'}]);
  $sth1->bind_param(41, $split_line[$field_columns{'dapimedianmaxperwell'}]);
  $sth1->bind_param(42, $split_line[$field_columns{'dapimedianminperwell'}]);
  $sth1->bind_param(43, $split_line[$field_columns{'dapimedianmedianperwell'}]);
  $sth1->bind_param(44, $split_line[$field_columns{'numberofcellperclumpsummeanperwe'}]);
  $sth1->bind_param(45, $split_line[$field_columns{'numberofcellperclumpsumstddevper'}]);
  $sth1->bind_param(46, $split_line[$field_columns{'numberofcellperclumpsumsumperwel'}]);
  $sth1->bind_param(47, $split_line[$field_columns{'numberofcellperclumpsummaxperwel'}]);
  $sth1->bind_param(48, $split_line[$field_columns{'numberofcellperclumpsumminperwel'}]);
  $sth1->bind_param(49, $split_line[$field_columns{'numberofcellperclumpsummedianper'}]);
  $sth1->bind_param(50, $split_line[$field_columns{'cellareammeanperwell'}]);
  $sth1->bind_param(51, $split_line[$field_columns{'cellareamstddevperwell'}]);
  $sth1->bind_param(52, $split_line[$field_columns{'cellareamsumperwell'}]);
  $sth1->bind_param(53, $split_line[$field_columns{'cellareammaxperwell'}]);
  $sth1->bind_param(54, $split_line[$field_columns{'cellareamminperwell'}]);
  $sth1->bind_param(55, $split_line[$field_columns{'cellareammedianperwell'}]);
  $sth1->bind_param(56, $split_line[$field_columns{'cellroundnessmeanperwell'}]);
  $sth1->bind_param(57, $split_line[$field_columns{'cellroundnessstddevperwell'}]);
  $sth1->bind_param(58, $split_line[$field_columns{'cellroundnesssumperwell'}]);
  $sth1->bind_param(59, $split_line[$field_columns{'cellroundnessmaxperwell'}]);
  $sth1->bind_param(60, $split_line[$field_columns{'cellroundnessminperwell'}]);
  $sth1->bind_param(61, $split_line[$field_columns{'cellroundnessmedianperwell'}]);
  $sth1->bind_param(62, $split_line[$field_columns{'cellratiowidthtolengthmeanperwel'}]);
  $sth1->bind_param(63, $split_line[$field_columns{'cellratiowidthtolengthstddevperw'}]);
  $sth1->bind_param(64, $split_line[$field_columns{'cellratiowidthtolengthsumperwell'}]);
  $sth1->bind_param(65, $split_line[$field_columns{'cellratiowidthtolengthmaxperwell'}]);
  $sth1->bind_param(66, $split_line[$field_columns{'cellratiowidthtolengthminperwell'}]);
  $sth1->bind_param(67, $split_line[$field_columns{'cellratiowidthtolengthmedianperw'}]);
  $sth1->bind_param(68, $split_line[$field_columns{'compound'}]);
  $sth1->bind_param(69, $split_line[$field_columns{'concentration'}]);
  $sth1->bind_param(70, $split_line[$field_columns{'count'}]);
  $sth1->bind_param(71, $split_line[$field_columns{'numberofanalyzedfields'}]);
  $sth1->execute;
}
close $IN;
