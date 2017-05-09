#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::GeneralUtils qw();
use ReseqTrack::Tools::FileSystemUtils qw(run_md5);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::QC1Samples;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Find qw();

my $es_host = 'ves-hx-e4:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $ftp_base = '/nfs/hipsci/vol1/ftp';
my $staging_base = '/nfs/1000g-work/hipsci/archive_staging/ftp';
my $aberrant_polysomy_dir = '/nfs/research2/hipsci/drop/hip-drop/incoming/keane/hipsci_data_030517/plots/aberrant_polysomy';


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
  my ($cell_line, $sample, $region) = $_ =~ /(HPSI\d+i-[a-z]+_\d+)_([^\.]+)\.aberrant_polysomy\.(.+)\.png/;
  return if !$cell_line;
  return if !$qc1->is_valid_gtarray($cell_line, $sample);
  my $es_line = $es->fetch_line_by_name($cell_line);
  die "did not recognise $cell_line" if !$es_line;
  my $match_expression = "$ftp_base/data/qc1_images/aberrant_polysomy/$cell_line/$cell_line.aberrant_polysomy.%.$region.png";
  $sth->bind_param(1, $match_expression);
  $sth->execute;
  my $rows = $sth->fetchall_arrayref({});
  die "multiple files found for $match_expression" if !@$rows > 1;
  if (!@$rows) {
    my $new_name = "$staging_base/data/qc1_images/aberrant_polysomy/$cell_line/$cell_line.aberrant_polysomy.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    return;
  }

  $processed_ftp_files{$rows->[0]->{name}} = 1;

  if ($rows->[0]->{size} != -s $File::Find::name) {
    my $new_name = "$staging_base/data/qc1_images/aberrant_polysomy/$cell_line/$cell_line.aberrant_polysomy.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
    return;
  }

  my $new_md5 = run_md5($File::Find::name);
  if ($new_md5 ne $rows->[0]->{md5}) {
    my $new_name = "$staging_base/data/qc1_images/aberrant_polysomy/$cell_line/$cell_line.aberrant_polysomy.$current_date.$region.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
  }

}

File::Find::find(\&wanted, $aberrant_polysomy_dir);
$sth2->bind_param("$ftp_base/data/qc1_images/aberrant_polysomy/%.png");
$sth2->execute;
ROW:
while (my $row = $sth2->fetchrow_hashref) {
  next ROW if $processed_ftp_files{$row->{name}};
  print "dearchive\t", $row->{name}, "\n";
}
