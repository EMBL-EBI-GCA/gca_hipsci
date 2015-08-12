#!/usr/bin/env perl

use strict;

use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::Tools::Exception;
use File::Copy qw(move);
use ReseqTrack::Tools::FileUtils qw(create_history);
use ReseqTrack::Tools::ArchiveUtils qw(create_archive_from_objects);
use File::Basename qw(dirname);
use ReseqTrack::Tools::FileSystemUtils qw(check_directory_exists);
use Getopt::Long;

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1krw';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $withdrawn_base = '/nfs/hipsci/vol1/withdrawn/';
my $ftp_base = '/nfs/hipsci/vol1/ftp';

&GetOptions( 
	    'dbhost=s'      => \$dbhost,
	    'dbname=s'      => \$dbname,
	    'dbuser=s'      => \$dbuser,
	    'dbpass=s'      => \$dbpass,
	    'dbport=s'      => \$dbport,
	    'withdrawn_base=s'      => \$withdrawn_base,
	    'ftp_base=s'      => \$ftp_base,
    );

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );

my $fa = $db->get_FileAdaptor;
my $archive_action_adaptor = $db->get_ArchiveActionAdaptor;
my $archive_location_adaptor = $db->get_ArchiveLocationAdaptor;
my $aa =  $db->get_ArchiveAdaptor;
my $action = $archive_action_adaptor->fetch_by_action('move_within_volume');
throw("Failed to get action for move_within_volume") unless($action);
my $location = $archive_location_adaptor->fetch_by_archive_location_name('archive');

my @archives;
FILE:
foreach my $from_object (@{$fa->fetch_all_withdrawn()}) {
  my $from_path = $from_object->name;
  next FILE if $from_path !~ /^$ftp_base/;
  my $new_path = $from_path;
  $new_path =~ s/^$ftp_base/$withdrawn_base/;
  $new_path =~ s{//}{/}g;

  my $archive = create_archive_from_objects($from_object, $action, $location, $new_path);
  push(@archives, $archive);
}

foreach my $archive(@archives){
  $archive->priority(99);
  $aa->store($archive);
}
$aa->delete_archive_lock;
