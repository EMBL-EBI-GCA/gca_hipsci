#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Registry; #From plantsTrackHubPipeline (https://github.com/EnsemblGenomes/plantsTrackHubPipeline)
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciTrackHubCreation;  #HipSci specifc version of TrackHubCreation module of the plantsTrackHubPipeline

my @exomeseq;
my ($registry_user_name,$registry_pwd);
my ($server_dir_full_path, $server_url, $from_scratch);

GetOptions(
  "THR_username=s"             => \$registry_user_name,
  "THR_password=s"             => \$registry_pwd,
  "server_dir_full_path=s"     => \$server_dir_full_path,
  "server_url=s"               => \$server_url,  
  "exomeseq=s"                 => \@exomeseq,
  "do_track_hubs_from_scratch" => \$from_scratch,  # flag
);

if(!$registry_user_name or !$registry_pwd or !$server_dir_full_path or !$server_url){
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
    my $ftpdata = $parts[0];
    #TODO may need to store additional information such as type of data for later
    if (exists($cell_lines{$study_id})){
      push($cell_lines{$study_id}, $ftpdata)
    }else{
      $cell_lines{$study_id} = [$ftpdata]
    }
  }
  close $fh;
}

my $registry_obj = Registry->new($registry_user_name, $registry_pwd);

if (!-d $server_dir_full_path) {
  my @args = ("mkdir", "$server_dir_full_path");
  system(@args) == 0 or die "system @args failed: $?";
}

my $pre_update_trackhub = print_registry_registered_number_of_th($registry_obj);

#TODO Make trackhubs and track whether successful
my $unsuccessful_studies = make_register_THs_with_logging($registry_obj, \%cell_lines , $server_dir_full_path); 

#Check and print reason for errors #TODO Check error calling
my $counter=0;
if(scalar (keys %$unsuccessful_studies) >0){
  print "\nThere were some studies that failed to be made track hubs:\n\n";
}
foreach my $reason_of_failure (keys %$unsuccessful_studies){  # hash looks like; $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;
  foreach my $failed_study_id (keys $unsuccessful_studies->{$reason_of_failure}){
    $counter ++;
    print "$counter. $failed_study_id\t".$reason_of_failure."\n";
  }
}

my $post_update_trackhub = print_registry_registered_number_of_th($registry_obj);

#TODO Make a summary output to print to log file, include $pre_update_trackhub_count and $post_update_trackhub_count

### Methods ###
sub make_register_THs_with_logging{

  my $registry_obj = shift;
  my $cell_lines_to_register = shift;
  my $server_dir_full_path = shift;

  my $return_string;
  my $line_counter = 0;
  my %unsuccessful_studies;

  #Remove existing trackhub folders 
  #TODO Add check for whether trackhub needs updating, 
  #can just save a copy of %cell_lines from previous run and then compare it to current 
  #run to see if update is required on per cell line basis
  foreach my $cell_line (keys %$cell_lines_to_register){
    $line_counter++;
    my $ls_output = `ls $server_dir_full_path`  ;
    my $flag_new_or_update;
    if($ls_output =~/$cell_line/){ # i check if the directory of the study exists already
      $flag_new_or_update = "update";
      my @args = ("rm", "-r", "$server_dir_full_path/$cell_line");
      system(@args) == 0 or die "system @args failed: $?";
    }
  
    my $track_hub_creator_obj = HipSciTrackHubCreation->new($cell_line,$server_dir_full_path);
    my $script_output = $track_hub_creator_obj->make_track_hub($cell_lines{$cell_line});
  
  }
  return (\%unsuccessful_studies);
}


sub print_registry_registered_number_of_th{

  my $registry_obj = shift;

  my $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
  return $all_track_hubs_in_registry_href; #TODO make print statement that counts distinct trackhubs

}