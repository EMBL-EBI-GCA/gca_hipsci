#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(dirname);

my $es_host='vg-rs-dev1:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $file_pattern = 'gtarray/hla_typing/%.fam';
my $trim = '/nfs/hipsci';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research2/hipsci/drop/hip-drop/tracked';

&GetOptions(
    'es_host=s' =>\$es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'file_pattern=s'      => \$file_pattern,
    'trim=s'      => \$trim,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );

my %cell_line_updates;
my $fa = $db->get_FileAdaptor;
FILE:
foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {
  my $ftp_path = $file->name;
  my $drop_path = $ftp_path;
  $drop_path =~ s{$drop_trim}{$drop_base};
  die "could not find corresponding file from $ftp_path $drop_path" if ! -f $drop_path;

  my $ftp_dir = dirname($ftp_path);
  $ftp_dir =~ s{$trim}{};

  open my $fh, '<', $drop_path or die "could not open $drop_path $!";
  CELL_LINE:
  while (my $line = <$fh>) {
    chomp $line;
    my ($cell_line_name) = split(/\s+/, $line);
    next CELL_LINE if !$cell_line_name;
    $cell_line_updates{$cell_line_name} = {
      hlaTyping => {
        archive => 'FTP',
        path => $ftp_dir,
      }
    };
  }
  close $fh;

}

CELL_LINE:
while (my ($ips_line, $update) = each %cell_line_updates) {
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line
  );
  next CELL_LINE if !$line_exists;
  $elasticsearch->update(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
    body => {doc => $update},
  );
}
