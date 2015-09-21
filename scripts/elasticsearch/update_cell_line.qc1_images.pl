#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use Data::Compare;
use Data::Dumper;
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my $es_host='vg-rs-dev1:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my @file_types = qw(COPY_NUMBER_PNG PLURITEST_PNG CNV_REGION_PNG);
my $trim = '/nfs/hipsci';

&GetOptions(
    'es_host=s' =>\$es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'file_type=s'      => \@file_types,
    'trim=s'      => \$trim,
);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

my $cell_updated = 0;
my $cell_uptodate = 0;
my $donor_updated = 0;
my $donor_uptodate = 0;

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );

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
      my $donor_exists = $elasticsearch->exists(
        index => 'hipsci',
        type => 'donor',
        id => $sample_name
      );
      next CELL_LINE if !$donor_exists;
      my $donor = $elasticsearch->get(
        index => 'hipsci',
        type => 'donor',
        id => $sample_name,
      );
      @cell_line_names = map {$_->{name}} @{$donor->{_source}{cellLines}};
    }

    $filepath =~ s{$trim}{};
    foreach my $cell_line_name (@cell_line_names) {
      if ($filename =~ /\.pluritest\.novelty_score\./) {
        $cell_line_updates{$cell_line_name}{pluritest}{novelty_image} = $filepath;
      }
      elsif ($filename =~ /\.pluritest\.pluripotency_score\./) {
        $cell_line_updates{$cell_line_name}{pluritest}{pluripotency_image} = $filepath;
      }
      elsif ($filename =~ /\.cnv_aberrant_regions\./) {
        $cell_line_updates{$cell_line_name}{cnv}{aberrant_images} //= [];
        push(@{$cell_line_updates{$cell_line_name}{cnv}{aberrant_images}}, $filepath);
      }
    }
  }
}

CELL_LINE:
while (my ($ips_line, $lineupdate) = each %cell_line_updates) {
  my $line_exists = $elasticsearch->exists(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line
  );
  next CELL_LINE if !$line_exists;
  my $original = $elasticsearch->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $ips_line,
  );
  my $update = $elasticsearch->get(
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
    $elasticsearch->update(
      index => 'hipsci',
      type => 'cellLine',
      id => $ips_line,
      body => {doc => $$update{'_source'}},
    );
    $cell_updated++;
  }
}

#TODO  Should send this to a log file
print "\n06update_qc1_images\n";
print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
print "Donors: $donor_updated updated, $donor_uptodate unchanged.\n";