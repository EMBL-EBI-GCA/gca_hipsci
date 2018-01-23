#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::GeneralUtils qw();
use ReseqTrack::Tools::FileSystemUtils qw(run_md5);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::QC1Samples;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Find qw();
use Getopt::Long;

my $es_host = 'ves-hx-e4:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $ftp_base = '/nfs/hipsci/vol1/ftp';
my $staging_base = '/nfs/1000g-work/hipsci/archive_staging/ftp';
my $aberrant_regions_dir = '/nfs/research1/hipsci/drop/hip-drop/incoming/keane/hipsci_data_030517/plots/cnv_aberrant_regions';

&GetOptions(
    'es_host=s'   => \$es_host,
    'dbhost=s'   => \$dbhost,
    'dbname=s'   => \$dbname,
    'dbuser=s'   => \$dbuser,
    'dbpass=s'   => \$dbpass,
    'dbport=s'   => \$dbport,
    'ftp_base=s'   => \$ftp_base,
    'staging_base=s'   => \$staging_base,
    'aberrant_regions_dir=s'   => \$aberrant_regions_dir,
);

my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
my $qc1 = ReseqTrack::Tools::HipSci::QC1Samples->new();

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
);
my $fa = $db->get_FileAdaptor;

my $current_date = ReseqTrack::Tools::GeneralUtils::current_date();

my $sql = 'select name, size, md5 from file where name like ?';
my $sth = $fa->prepare($sql);
my $sql2 = 'select name from file where name like ?';
my $sth2 = $fa->prepare($sql2);

my %processed_ftp_files;

sub wanted {
  return if ! -f $_;
  my ($cell_line, $sample, $region) = $_ =~ /(HPSI\d+i-[a-z]+_\d+)_([^\.]+)\.cnv_aberrant_regions\.(.+)\.png/;
  return if !$cell_line;
  return if !$qc1->is_valid_gtarray($cell_line, $sample);
  my $es_line = $es->fetch_line_by_name($cell_line);
  die "did not recognise $cell_line" if !$es_line;
  my $match_expression = "$ftp_base/data/qc1_images/cnv_aberrant_regions/$cell_line/$cell_line.cnv_aberrant_regions.%.$region.png";
  $sth->bind_param(1, $match_expression);
  $sth->execute;
  my $rows = $sth->fetchall_arrayref({});
  die "multiple files found for $match_expression" if !@$rows > 1;
  if (!@$rows) {
    my $new_name = "$staging_base/data/qc1_images/cnv_aberrant_regions/$cell_line/$cell_line.cnv_aberrant_regions.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    return;
  }

  $processed_ftp_files{$rows->[0]->{name}} = 1;

  if ($rows->[0]->{size} != -s $File::Find::name) {
    my $new_name = "$staging_base/data/qc1_images/cnv_aberrant_regions/$cell_line/$cell_line.cnv_aberrant_regions.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
    return;
  }

  my $new_md5 = run_md5($File::Find::name);
  if ($new_md5 ne $rows->[0]->{md5}) {
    my $new_name = "$staging_base/data/qc1_images/cnv_aberrant_regions/$cell_line/$cell_line.cnv_aberrant_regions.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
  }

}

File::Find::find(\&wanted, $aberrant_regions_dir);
$sth2->bind_param(1, "$ftp_base/data/qc1_images/cnv_aberrant_regions/%.png");
$sth2->execute;
ROW:
while (my $row = $sth2->fetchrow_hashref) {
  next ROW if $processed_ftp_files{$row->{name}};
  print "dearchive\t", $row->{name}, "\n";
}

=pod

=head1 NAME

$GCA_HIPSCI/scripts/qc1/cnv_aberrant_regions_to_public_ftp.pl

=head1 SYNOPSIS

Our friends at WTSI occasionally copy a complete new set of QC1 data onto disk in Hinxton.
The QC1 files are archived on our public FTP site which is on disk in Hemel.

This script looks at the new QC1 files and works out:

  1. which qc1 files are new (not yet on the public FTP site) - these files 
     must be copied from Hinxton to Hemel, loaded into the database, and archived.

  2. which FTP files are old - these files must be dearchived from the public FTP site

This script uses file sizes and md5s to work out if a FTP file is different from the new version.
This script is responsible for working out the correct name and file path of the incoming data.

This script does not take any action itself: The stdout from this script is a list of commands, which should be fed into the script run_actions.pl as stdin

=head1 Example

perl cnv_aberrant_regions_to_public_ftp.pl -aberrant_regions_dir=/path/to/plots/cnv_aberrant_regions > actions.txt

=head1 OPTIONS

  -aberrant_regions_dir: this must be the full path to a directory in Hinxton created by WTSI, usually called "plots/cnv_aberrant_regions"

  -dbpass: no default
  -dbhost: default is mysql-g1kdcc-public
  -dbuser: default is g1kro
  -dbport: default is 4197
  -dbname: default is hipsci_track
  -ftp_base: default is /nfs/hipsci/vol1/ftp
  -staging_base: default is /nfs/1000g-work/hipsci/archive_staging/ftp

=head1 REQUIREMENTS

You must run this script from Hinxton.

Note, the run_action.pl script should be run in Hemel. Therefore you will need to manually scp the stdout from this script from Hinxton to Hemel before you run run_actions.pl.

=cut
