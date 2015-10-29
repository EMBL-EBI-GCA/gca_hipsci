#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
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
my $file_type = 'CELLBIOL-FN_MISC';
my $trim = '/nfs/hipsci';

&GetOptions(
  'es_host=s' =>\@es_host,
  'dbhost=s'  => \$dbhost,
  'dbname=s'  => \$dbname,
  'dbuser=s'  => \$dbuser,
  'dbpass=s'  => \$dbpass,
  'dbport=s'  => \$dbport,
  'file_type=s'  => \$file_type,
  'trim=s'  => \$trim,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}

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
  next CELL_LINE if $file->name !~ /pdf$/;
  my $dir = dirname($file->name);
  my ($cell_line_name) = $dir =~ m{/(HPSI[^/]*)};
  next CELL_LINE if !$cell_line_name;
  $dir =~ s{$trim}{};
  $cell_line_updates{$cell_line_name} = {
    assays => { 'cellbiol-fn' => {
      archive => 'FTP',
      path => $dir,
      name => 'Cellular phenotyping',
      ontologyPURL => 'http://www.ebi.ac.uk/efo/EFO_0005399'
    }}
  };
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){

  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $scroll = $elasticsearchserver->call('scroll_helper',
    index       => 'hipsci',
    type        => 'cellLine',
    search_type => 'scan',
    size        => 500
  );

  CELL_LINE:
  while ( my $doc = $scroll->next ) {
    my $update = $elasticsearchserver->fetch_line_by_name($$doc{'_source'}{'name'});
    delete $$update{'_source'}{'assays'}{'cellbiol-fn'};
    if (! scalar keys $$update{'_source'}{'assays'}){
      delete $$update{'_source'}{'assays'};
    }
    if ($cell_line_updates{$$doc{'_source'}{'name'}}){
      my $lineupdate = $cell_line_updates{$$doc{'_source'}{'name'}};
      foreach my $field (keys $lineupdate){
        foreach my $subfield (keys $$lineupdate{$field}){
          $$update{'_source'}{$field}{$subfield} = $$lineupdate{$field}{$subfield};
        }
      }
    }
    if (Compare($$update{'_source'}, $$doc{'_source'})){
      $cell_uptodate++;
    }else{
      $$update{'_source'}{'_indexUpdated'} = $date;
      $elasticsearchserver->index_line(id => $$doc{'_source'}{'name'}, body => $$update{'_source'});
      $cell_updated++;
    }
  }
  print "\n$host\n";
  print "07update_cellbiol-fn\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}