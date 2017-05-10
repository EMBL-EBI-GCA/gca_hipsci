#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::GeneralUtils qw();
use ReseqTrack::Tools::FileSystemUtils qw(run_md5);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
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
my $pluritest_dir = '/nfs/research2/hipsci/drop/hip-drop/incoming/keane/hipsci_data_030517/plots/pluritest';

&GetOptions(
    'es_host=s'   => \$es_host,
    'dbhost=s'   => \$dbhost,
    'dbname=s'   => \$dbname,
    'dbuser=s'   => \$dbuser,
    'dbpass=s'   => \$dbpass,
    'dbport=s'   => \$dbport,
    'ftp_base=s'   => \$ftp_base,
    'staging_base=s'   => \$staging_base,
    'pluritest_dir=s'   => \$pluritest_dir,
);


my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

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

my %png_type = (
  1 => 'pluripotency_score',
  2 => 'novelty_score',
  3 => 'pluripotency_vs_novelty',
  4 => 'clustering',
  5 => 'microarray_intensity',
);

my %processed_ftp_files;

sub wanted {
  return if ! -f $_;
  my ($short_name, $png_num) = $_ =~ /HPSI\d+-([a-z]+)\.pluritest\.(\d+)\.png/;
  return if !$short_name || !$png_num;
  my $donor = $es->fetch_donor_by_short_name($short_name, fuzzy => 1);
  die "no donor for $short_name" if !$donor;
  my $donor_name = $donor->{_source}{name};
  my $png_type = $png_type{$png_num};
  my $match_expression = "$ftp_base/data/qc1_images/pluritest/$donor_name/$donor_name.pluritest.$png_type.%.png";
  $sth->bind_param(1, $match_expression);
  $sth->execute;
  my $rows = $sth->fetchall_arrayref({});
  die "multiple files found for $match_expression" if !@$rows > 1;
  if (!@$rows) {
    my $new_name = "$staging_base/data/qc1_images/pluritest/$donor_name/$donor_name.pluritest.$png_type.$current_date.png";
    print "archive\t$File::Find::name\t$new_name\n";
    return;
  }

  $processed_ftp_files{$rows->[0]->{name}} = 1;

  if ($rows->[0]->{size} != -s $File::Find::name) {
    my $new_name = "$staging_base/data/qc1_images/pluritest/$donor_name/$donor_name.pluritest.$png_type.$current_date.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
    return;
  }

  my $new_md5 = run_md5($File::Find::name);
  if ($new_md5 ne $rows->[0]->{md5}) {
    my $new_name = "$staging_base/data/qc1_images/pluritest/$donor_name/$donor_name.pluritest.$png_type.$current_date.png";
    print "archive\t$File::Find::name\t$new_name\n";
    print "dearchive\t", $rows->[0]->{name}, "\n";
  }

}

File::Find::find(\&wanted, $pluritest_dir);
$sth2->bind_param("$ftp_base/data/qc1_images/pluritest/%.png");
$sth2->execute;
ROW:
while (my $row = $sth2->fetchrow_hashref) {
  next ROW if $processed_ftp_files{$row->{name}};
  print "dearchive\t", $row->{name}, "\n";
}
