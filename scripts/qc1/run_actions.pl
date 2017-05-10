#!/usr/bin/env perl
use strict;
use warnings;
use File::Rsync;
use Getopt::Long;
use ReseqTrack::Tools::Loader;
use ReseqTrack::Tools::Loader::Archive;

my $hx_host = 'ebi-cli-003';
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1krw';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';

&GetOptions(
    'hx_host=s'   => \$hx_host,
    'dbhost=s'   => \$dbhost,
    'dbname=s'   => \$dbname,
    'dbuser=s'   => \$dbuser,
    'dbpass=s'   => \$dbpass,
    'dbport=s'   => \$dbport,
);

my $rsync = File::Rsync->new;

my @archive_files;
my @dearchive_files;
while (my $line = <STDIN>) {
  chomp $line;
  my @split_line = split("\t", $line);
  if ($split_line[0] eq 'archive') {
    my ($scp_from, $scp_to) = @split_line[1,2];
    $rsync->exec("$hx_host:$scp_from", $scp_to) or die join("\n", "rsync error", $rsync->err);
    push(@archive_files, $scp_to);
  } elsif ($split_line[0] eq 'dearchive') {
    push(@dearchive_files, $split_line[1]);
  } else {
    die "did not understand action $line";
  }
}

if (scalar @archive_files) {
  my $loader = ReseqTrack::Tools::Loader::File->new(
    -file => \@archive_files,
    -dbhost => $dbhost,
    -dbname => $dbname,
    -dbuser => $dbuser,
    -dbpass => $dbpass,
    -dbport => $dbport,
    -assign_types => 1,
    -do_md5 => 1,
  );
  $loader->process_input();
  $loader->create_objects();
  $loader->sanity_check_objects();
  $loader->load_objects();

  my $archiver = ReseqTrack::Tools::Loader::Archive->new(
    -file => \@archive_files,
    -dbhost => $dbhost,
    -dbname => $dbname,
    -dbuser => $dbuser,
    -dbpass => $dbpass,
    -dbport => $dbport,
    -action => 'archive',
  );
  $archiver->process_input();
  $archiver->sanity_check_objects();
  $archiver->archive_objects();
}

if (scalar @dearchive_files) {
  my $archiver = ReseqTrack::Tools::Loader::Archive->new(
    -file => \@archive_files,
    -dbhost => $dbhost,
    -dbname => $dbname,
    -dbuser => $dbuser,
    -dbpass => $dbpass,
    -dbport => $dbport,
    -action => 'dearchive',
  );
  $archiver->process_input();
  $archiver->sanity_check_objects();
  $archiver->archive_objects();
}
