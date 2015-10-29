#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use Data::Compare;
use Data::Dumper;
use File::Basename;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $trim = '/nfs/hipsci';

&GetOptions(
  'es_host=s' =>\@es_host,
  'dbhost=s'      => \$dbhost,
  'dbname=s'      => \$dbname,
  'dbuser=s'      => \$dbuser,
  'dbpass=s'      => \$dbpass,
  'dbport=s'      => \$dbport,
  'trim=s'      => \$trim,
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

my %coa_urls;
my $fa = $db->get_FileAdaptor;
CELL_LINE:
foreach my $file (@{$fa->fetch_by_type("COA_PDF")}) {
  my ($filename, $dirs) = fileparse($$file{'name'});
  my $samplename = (split /\./, $filename)[0];
  $dirs =~ s?/nfs/hipsci?http://ftp.hipsci.ebi.ac.uk?;
  my $url = $dirs.$filename;
  $coa_urls{$samplename} = $url;
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
    my $update = clone $doc;
    delete $$update{'_source'}{'certificateOfAnalysis'};
    if ($coa_urls{$$doc{'_source'}{'name'}}){
      $$update{'_source'}{'certificateOfAnalysis'}{'url'} = $coa_urls{$$doc{'_source'}{'name'}};
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
  print "13update_coa\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";

}
