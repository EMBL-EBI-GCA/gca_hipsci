#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);
use Data::Dumper;

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my @file_types = qw(COPY_NUMBER_PNG PLURITEST_PNG CNV_REGION_PNG);
my $trim = '/nfs/hipsci';

&GetOptions(
  'es_host=s' =>\@es_host,
  'dbhost=s'      => \$dbhost,
  'dbname=s'      => \$dbname,
  'dbuser=s'      => \$dbuser,
  'dbpass=s'      => \$dbpass,
  'dbport=s'      => \$dbport,
  'file_type=s'      => \@file_types,
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

my %aberrant_regions;
my %cell_line_updates;
my $fa = $db->get_FileAdaptor;
foreach my $file_type (@file_types) {
  CELL_LINE:
  foreach my $file (@{$fa->fetch_by_type($file_type)}) {
    next CELL_LINE if $file->withdrawn;
    my $filepath = $file->name;
    next CELL_LINE if $filepath !~ /\.png$/;
    next CELL_LINE if $filepath =~ /withdrawn/;
    next CELL_LINE if $filepath !~ m{/qc1_images/};
    my $filename = fileparse($filepath);
    my ($sample_name) = $filename =~ /^(HPSI[^\.]*)\./;
    next CELL_LINE if !$sample_name;
    my @cell_line_names = ($sample_name);
    if ($sample_name =~ /HPSI-/) {
      my $donor_exists = $elasticsearch{$es_host[0]}->call('exists',
        index => 'hipsci',
        type => 'donor',
        id => $sample_name
      );
      next CELL_LINE if !$donor_exists;
      my $donor = $elasticsearch{$es_host[0]}->fetch_donor_by_name($sample_name);
      @cell_line_names = map {$_->{name}} @{$donor->{_source}{cellLines}};
    }

    my $is_ftp = $filepath =~ s{$trim}{};
    next CELL_LINE if !$is_ftp;
    foreach my $cell_line_name (@cell_line_names) {
      if ($filename =~ /\.pluritest\.novelty_score\./) {
        $cell_line_updates{$cell_line_name}{pluritest}{novelty_image} = $filepath;
      }
      elsif ($filename =~ /\.pluritest\.pluripotency_score\./) {
        $cell_line_updates{$cell_line_name}{pluritest}{pluripotency_image} = $filepath;
      }
      elsif ($filename =~ /\.copy_number\./) {
        $cell_line_updates{$cell_line_name}{cnv}{summary_image} = $filepath;
      }
      elsif ($filename =~ /\.cnv_aberrant_regions\./) {
        $cell_line_updates{$cell_line_name}{cnv}{aberrant_images} //= [];
        #Extract chromosome number from filename e.g. chr3
        my @filepathparts = split(/\./, $filepath);
        my $chromosome = $filepathparts[-3];
        if (!exists $aberrant_regions{$cell_line_name}{$chromosome}){  # For each CellLine check whether an image for this chromosome has been stored yet
          push(@{$cell_line_updates{$cell_line_name}{cnv}{aberrant_images}}, $filepath);  # Only store 1 image per chromosome
          $aberrant_regions{$cell_line_name}{$chromosome} = 1;
        }
      }
    }
  }
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
    delete $$update{'_source'}{'cnv'}{aberrant_images};
    delete $$update{'_source'}{'cnv'}{summary_image};
    if (! scalar keys $$update{'_source'}{'cnv'}){
      delete $$update{'_source'}{'cnv'};
    }
    delete $$update{'_source'}{'pluritest'}{novelty_image};
    delete $$update{'_source'}{'pluritest'}{pluripotency_image};
    if (! scalar keys $$update{'_source'}{'pluritest'}){
      delete $$update{'_source'}{'pluritest'};
    }
    if (my $lineupdate = $cell_line_updates{$$doc{'_source'}{'name'}}){

      # Only add a cnv summary image if we know the cell line has cnv information
      # We do this because cnv images are per-donor
      if ($lineupdate->{cnv}{summary_image} && !$update->{_source}{cnv}) {
        delete $lineupdate->{cnv}{summary_image};
      }

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
  print "05_update_qc1_images\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
}
