#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(dirname);
use Data::Compare;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $file_type = 'PROTEOMICS_RAW';
my $trim = '/nfs/hipsci';

&GetOptions(
    'es_host=s' =>\@es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'file_type=s'      => \$file_type,
    'trim=s'      => \$trim,
);

my @elasticsearch;
foreach my $es_host (@es_host){
  push(@elasticsearch, Search::Elasticsearch->new(nodes => $es_host));
}

my $cell_updated = 0;
my $cell_uptodate = 0;

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
while (my ($ips_line, $lineupdate) = each %cell_line_updates) {
  my $line_exists = $elasticsearch[0]->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line
  );
  next CELL_LINE if !$line_exists;
  my $original = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  my $update = $elasticsearch[0]->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  foreach my $field (keys $lineupdate){
    foreach my $subfield (keys $$lineupdate{$field}){
      $$update{'_source'}{$field}{$subfield} = $$lineupdate{$field}{$subfield};
    }
  }
  if (Compare($$update{'_source'}, $$original{'_source'})){
    $cell_uptodate++;
  }else{
    $$update{'_source'}{'indexUpdated'} = $date;
    foreach my $elasticsearchserver (@elasticsearch){
      $elasticsearchserver->update(
        index => 'hipsci',
        type => 'cellLine',
        id => $ips_line,
        body => {doc => $$update{'_source'}},
      );
    }
    $cell_updated++;
  }

}

#TODO  Should send this to a log file
print "\n05update_proteomics\n";
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";