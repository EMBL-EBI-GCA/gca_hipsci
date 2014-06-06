#!/usr/bin/env perl

use strict;

use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::Tools::Exception;
use File::Copy qw(move);
use ReseqTrack::Tools::FileUtils qw(create_history);
use Getopt::Long;

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1krw';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $clobber = 0;
my $from;
my $to;

&GetOptions( 
	    'dbhost=s'      => \$dbhost,
	    'dbname=s'      => \$dbname,
	    'dbuser=s'      => \$dbuser,
	    'dbpass=s'      => \$dbpass,
	    'dbport=s'      => \$dbport,
	    'from=s'      => \$from,
	    'to=s'      => \$to,
	    'clobber!' => \$clobber,
    );

throw("no from") if !$from;
throw("no to") if !$to;

foreach ($from, $to) {
  s{//*}{/}g;
  s{/$}{};
}

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );

throw("cannot move") if (-f $to && !$clobber);

my $fa = $db->get_FileAdaptor;
my $from_object = $fa->fetch_by_name($from);
throw("no file") if !$from_object;
my $to_object = $fa->fetch_by_name($from);
$to_object->name($to);
my $history = create_history($to_object, $from_object);
$to_object->history($history);
$fa->update($to_object, 0, 1);
move($from, $to);
