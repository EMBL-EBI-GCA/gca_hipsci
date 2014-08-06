#!/usr/bin/env perl

use strict;
use warnings;

use HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
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
) or die $DBI::errstr;

my $sql1 = <<"SQL";
  INSERT INTO experiment (
    cell_line_id, w_field_id, cell_file_name,
    platform, form_factor, p_col,
    p_row, channel, dye, composite_color, name_measure,
    w_field_x, w_field_y, z, z_offset, pixel_size,
    marker, barcode, date_stained, date_read
  )
  VALUES (
      (SELECT cell_line_id FROM cell_line WHERE short_name = ?),
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
  )
SQL
my $sth1 = $dbh->prepare($sql1);

my $experiment_file = new Text::Delimited;
$experiment_file->delimiter("\t");
$experiment_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $experiment_file->read) {
  $sth1->bind_param(1, $line_data->{'line'}),
  $sth1->bind_param(2, $line_data->{'wFieldID'}),
  $sth1->bind_param(3, $line_data->{'CellFileName'}),
  $sth1->bind_param(4, $line_data->{'platform'}),
  $sth1->bind_param(5, $line_data->{'formFactor'}),
  $sth1->bind_param(6, $line_data->{'pCol'}),
  $sth1->bind_param(7, $line_data->{'pRow'}),
  $sth1->bind_param(8, $line_data->{'channel'}),
  $sth1->bind_param(9, $line_data->{'Dye'}),
  $sth1->bind_param(10, $line_data->{'CompositeColor'}),
  $sth1->bind_param(11, $line_data->{'nameMeasure'}),
  $sth1->bind_param(12, $line_data->{'wFieldX'}),
  $sth1->bind_param(13, $line_data->{'wFieldY'}),
  $sth1->bind_param(14, $line_data->{'Z'}),
  $sth1->bind_param(15, $line_data->{'ZOffset'}),
  $sth1->bind_param(16, $line_data->{'pixelSize'}),
  $sth1->bind_param(17, $line_data->{'marker'}),
  $sth1->bind_param(18, $line_data->{'barcode'}),
  $sth1->bind_param(19, $line_data->{'date_stained'}),
  $sth1->bind_param(20, $line_data->{'date_read'}),
  $sth1->execute;
}
$experiment_file->close;
