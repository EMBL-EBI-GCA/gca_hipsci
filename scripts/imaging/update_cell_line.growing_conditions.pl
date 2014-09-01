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


my $ips_lines = read_cgap_report()->{ips_lines};

my $sql1 = <<"SQL";
  UPDATE cell_line 
  SET
    is_on_feeder = ?
  WHERE
    biosample_id = ?
SQL

my $sth1 = $dbh->prepare($sql1);

my %is_feeder_free;
my $feeder_file = new Text::Delimited;
$feeder_file->delimiter(";");
$feeder_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $feeder_file->read) {
  next LINE if !$line_data->{sample} || !$line_data->{is_feeder_free};
  $is_feeder_free{$line_data->{sample}} = $line_data->{is_feeder_free};
}
$feeder_file->close;

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  next IPS_LINE if !$ips_line->biosample_id;
  my ($uuid) = $ips_line->uuid;
  next IPS_LINE if !$is_feeder_free{$uuid};

  $sth1->bind_param(1, $is_feeder_free{$uuid} eq 'Y' ? 0
                    : $is_feeder_free{$uuid} eq 'N' ? 1
                    : undef);
  $sth1->bind_param(2, $ips_line->biosample_id);
  $sth1->execute;

}
