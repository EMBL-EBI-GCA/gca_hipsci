#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciRegistry;  # HipSci specifc version of Registry module of the plantsTrackHubPipeline
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciTrackHubCreation;  # HipSci specifc version of TrackHubCreation module of the plantsTrackHubPipeline

my @exomeseq;  # Data types
my ($registry_user_name,$registry_pwd);
my ($server_dir_full_path, $server_url, $about_url, $hubname, $long_description, $email);
my @assemblies;

GetOptions(
  "THR_username=s"             => \$registry_user_name,
  "THR_password=s"             => \$registry_pwd,
  "server_dir_full_path=s"     => \$server_dir_full_path,
  "server_url=s"               => \$server_url,
  "hubname=s"                  => \$hubname,
  "long_description=s"         => \$long_description,
  "email=s"                    => \$email,
  "assembly=s"                 => \@assemblies,
  "about_url=s"                => \$about_url,
  "exomeseq=s"                 => \@exomeseq,
);

if(!$registry_user_name or !$registry_pwd or !$server_dir_full_path or !$server_url or !@assemblies or !$hubname){
  die "\nMissing required options\n";
}

my %cell_lines;

#TODO Add other data types
foreach my $enaexomeseq (@exomeseq){
  open my $fh, '<', $enaexomeseq or die $!;
  <$fh>;
  while (my $line = <$fh>) {
    next unless $line =~ /^ftp/;
    #TODO filter which specific file to select if not all of them
    chomp $line;
    my @parts = split("\t", $line);
    my $study_id = $parts[2];
    my @type_parts = split('\.', $parts[0]);
    my $type = $type_parts[-1];
    if ($type eq 'gz'){
      $type = $type_parts[-2]
    }
    my $ftpdata = {
      file_url => $parts[0],
      biosample_id => $parts[3],
      label => 'exomeseq',
      description => $parts[5],
      archive_submission_date => $parts[6],
      type => $type,
    };
    if (exists($cell_lines{$study_id})){
      push($cell_lines{$study_id}{data}, $ftpdata)
    }else{
      $cell_lines{$study_id} = {
        biosample_id => $parts[3],
        data => [$ftpdata]
      }
    }
  }
  close $fh;
}

my $registry_obj = HipSciRegistry->new($registry_user_name, 
                                       $registry_pwd,
                                       'hidden');  # For testing can make TrackHubs hidden from public view

if (!-d $server_dir_full_path) {
  my @args = ("mkdir", "$server_dir_full_path");
  system(@args) == 0 or die "system @args failed: $?";
}

my $pre_update_trackhub = print_registry_registered_number_of_th($registry_obj);

make_register_THs_with_logging($registry_obj, \%cell_lines , $server_dir_full_path, $hubname, $long_description, $email, \@assemblies); 

my $post_update_trackhub = print_registry_registered_number_of_th($registry_obj);

#TODO Make a summary output to print to log file, include $pre_update_trackhub_count and $post_update_trackhub_count

### Methods ###
sub make_register_THs_with_logging{

  my $registry_obj = shift;
  my $cell_lines_to_register = shift;
  my $server_dir_full_path = shift;
  my $hubname = shift;
  my $long_description = shift;
  my $email = shift;
  my $assemblies = shift;
  
  my $ls_output = `ls $server_dir_full_path`  ;
  my $flag_new_or_update;
  if($ls_output =~/$hubname/){ # i check if the directory of the study exists already
    my @args = ("rm", "-r", "$server_dir_full_path/$hubname");
    system(@args) == 0 or die "system @args failed: $?";
    $registry_obj->delete_track_hub($hubname);
  }
  
  my $track_hub_creator_obj = HipSciTrackHubCreation->new($cell_lines_to_register, $server_dir_full_path, $hubname, $long_description, $email, $assemblies, $about_url);
  $track_hub_creator_obj->make_track_hub();
  
  my $output = register_track_hub_in_TH_registry($registry_obj,$hubname);
}

sub register_track_hub_in_TH_registry{
  my $registry_obj = shift;
  my $hubname = shift;
 
  my $hub_txt_url = $server_url . "/" . $hubname . "/hub.txt" ;

  my $output = $registry_obj->register_track_hub($hubname,$hub_txt_url);
  return $output;
  
}

sub print_registry_registered_number_of_th{
  my $registry_obj = shift;
  my $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
  return $all_track_hubs_in_registry_href; #TODO make print statement that counts distinct trackhubs
}