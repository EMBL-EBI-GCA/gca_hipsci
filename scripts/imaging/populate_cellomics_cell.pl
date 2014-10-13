#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Text::Delimited;
use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellomics';
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
  {AutoCommit => 0},
) or die $DBI::errstr;

$dbh->do('SET foreign_key_checks=0') or die $dbh->errstr;

my $sql1 = <<"SQL";
  INSERT INTO cell (
    experiment_id, x_centroid, y_centroid, x_left,
    y_top, height, width, area, shape_p2a, shape_lwr,
    total_inten, avg_inten, var_inten
  )
  VALUES (
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
  )
SQL
my $sql2 = 'SELECT experiment_id, w_field_id, channel FROM experiment WHERE barcode = ?';
my $sth1 = $dbh->prepare($sql1);
my $sth2 = $dbh->prepare($sql2);

my %experiment_ids;

my $cell_file = new Text::Delimited;
$cell_file->delimiter("\t");
$cell_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $cell_file->read) {
  if (!$experiment_ids{$line_data->{'barcode'}}) {
    $sth2->bind_param(1, $line_data->{'barcode'}),
    $sth2->execute or die "could not process ".$line_data->{'__LINE__'};
    while (my $row = $sth2->fetchrow_arrayref) {
      $experiment_ids{$line_data->{'barcode'}}{$row->[2]}{$row->[1]} = $row->[0];
    }
  }
  my $experiment_id = $experiment_ids{$line_data->{'barcode'}}{$line_data->{'channel'}}{$line_data->{'wFieldID'}};
  if (!$experiment_id) {
    throw( "do not have experiment_id for ".$line_data->{'__LINE__'});
  }

  $sth1->bind_param(1, $experiment_id);
  $sth1->bind_param(2, $line_data->{'XCentroid'}),
  $sth1->bind_param(3, $line_data->{'YCentroid'}),
  $sth1->bind_param(4, $line_data->{'Left'}),
  $sth1->bind_param(5, $line_data->{'Top'}),
  $sth1->bind_param(6, $line_data->{'Height'}),
  $sth1->bind_param(7, $line_data->{'Width'}),
  $sth1->bind_param(8, $line_data->{'Area'}),
  $sth1->bind_param(9, $line_data->{'ShapeP2A'}),
  $sth1->bind_param(10, $line_data->{'ShapeLWR'}),
  $sth1->bind_param(11, $line_data->{'TotalInten'}),
  $sth1->bind_param(12, $line_data->{'AvgInten'}),
  $sth1->bind_param(13, $line_data->{'VarInten'}),
  $sth1->execute or die "could not process ".$line_data->{'__LINE__'};
  last LINE;
}
$cell_file->close;

$dbh->commit or die $dbh->errstr;
$dbh->do('SET foreign_key_checks=1') or die $dbh->errstr;
#$dbh->disconnect or die $dbh->errstr;
