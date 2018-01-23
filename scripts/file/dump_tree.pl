#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Find qw();
use File::stat;
use File::Spec;
use Time::localtime;

use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::File;

$| = 1;

my $dbhost;
my $dbuser;
my $dbpass;
my $dbport = 4197;
my $dbname;
my $tree_dir = '/nfs/research1/hipsci/drop/hip-drop/tracked';
my $relative_to_dir = '/nfs/research1/hipsci/drop/hip-drop';

&GetOptions(
  'dbhost=s'       => \$dbhost,
  'dbname=s'       => \$dbname,
  'dbuser=s'       => \$dbuser,
  'dbpass=s'       => \$dbpass,
  'dbport=s'       => \$dbport,
  'tree_dir=s'       => \$tree_dir,
  'relative_to_dir=s'       => \$relative_to_dir,
   );

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
    -host   => $dbhost,
    -user   => $dbuser,
    -port   => $dbport,
    -dbname => $dbname,
    -pass   => $dbpass,
);
my $fa = $db->get_FileAdaptor;

File::Find::find( sub {
  return if /^\./;
  return if -d $_;
  my $file = $fa->fetch_by_name($File::Find::name);
  throw("no file in db $File::Find::name") if !$file;
  my $mtime = ctime(stat($File::Find::name)->mtime);
  my $rel_path = File::Spec->abs2rel($File::Find::name, $relative_to_dir);
  print join("\t", $rel_path, $file->size, $file->md5, $mtime), "\n";
}, $tree_dir);
