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
my $file_type = 'PROTEOMICS_RAW';
my $trim = '/nfs/hipsci';

&GetOptions(
    'es_host=s' =>\$es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'file_type=s'      => \$file_type,
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
CELL_LINE:
foreach my $file (@{$fa->fetch_by_type($file_type)}) {
  my $dir = dirname($file->name);
  my ($cell_line_name) = $dir =~ m{/(HPSI[^/]*)};
  next CELL_LINE if !$cell_line_name;
  $dir =~ s{$trim}{};
  $cell_line_updates{$cell_line_name} = {
    assays => { proteomics => {
      archive => 'FTP',
      path => $dir,
      name => 'Proteomics',
      ontologyPURL => 'http://www.ebi.ac.uk/efo/EFO_0002766'
    }}
  };
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
