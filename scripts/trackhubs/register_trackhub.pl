#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciRegistry;

my ($registry_user_name,$registry_pwd);
my ($server_url, $hubname, $update_existing);

GetOptions(
  "THR_username=s"             => \$registry_user_name,
  "THR_password=s"             => \$registry_pwd,
  "server_url=s"               => \$server_url,
  "hubname=s"                  => \$hubname,
  "update_existing"            => \$update_existing,
);

if(!$registry_user_name or !$registry_pwd or !$server_url or !$hubname){
  die "\nMissing required options\n";
}

my $registry_obj = HipSciRegistry->new($registry_user_name, 
                                       $registry_pwd,
                                       'public',
#                                       'hidden',  # For testing can make TrackHubs hidden from public view
                                       );  

#If track already exists it should be deleted before the update
if ($update_existing){
  $registry_obj->delete_track_hub($hubname);
}

register_track_hub_in_TH_registry($registry_obj, $server_url, $hubname);



sub register_track_hub_in_TH_registry{
  my $registry_obj = shift;
  my $server_url = shift;
  my $hubname = shift;
 
  my $hub_txt_url = $server_url . "/" . $hubname . "/hub.txt" ;

  my $output = $registry_obj->register_track_hub($hubname,$hub_txt_url);
  print $output, "\n";
  
}