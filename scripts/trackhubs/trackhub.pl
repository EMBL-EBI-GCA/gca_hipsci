#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

#Existing imports from plantsTrackHubPipeline, could use HipSci specific version
use Registry;

#HipSci specifc versions of modules, could be merged into universal library with plantsTrackHubPipeline
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciTrackHubCreation;

###############################################
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
my %unsuccessful_studies;

foreach my $enaexomeseq (@exomeseq){
  open my $fh, '<', $enaexomeseq or die $!;
  <$fh>;
  while (my $line = <$fh>) {
    next unless $line =~ /^ftp/;
    chomp $line;
    my @parts = split("\t", $line);
    if (exists($cell_lines{$parts[2]})){
      push($cell_lines{$parts[2]}, $parts[0])
    }else{
      $cell_lines{$parts[2]} = [$parts[0]]
    }
  }
  close $fh;
}

my $registry_obj = Registry->new($registry_user_name, $registry_pwd);

if (!-d $server_dir_full_path) {
  my @args = ("mkdir", "$server_dir_full_path");
  system(@args) == 0 or die "system @args failed: $?";
}

#Count exisitng trackhubs
#print_registry_registered_number_of_th($registry_obj);

#TODO Make trackhubs

my $unsuccessful_studies_href = make_register_THs_with_logging($registry_obj, \%cell_lines , $server_dir_full_path); 

my $counter=0;

if(scalar (keys %$unsuccessful_studies_href) >0){
  print "\nThere were some studies that failed to be made track hubs:\n\n";
}

foreach my $reason_of_failure (keys %$unsuccessful_studies_href){  # hash looks like; $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;

  foreach my $failed_study_id (keys $unsuccessful_studies_href->{$reason_of_failure}){

    $counter ++;
    print "$counter. $failed_study_id\t".$reason_of_failure."\n";
  }
}

#Trackhubs post update
#print_registry_registered_number_of_th($registry_obj);


### Methods ###
sub make_register_THs_with_logging{

  my $registry_obj = shift;
  my $cell_lines_to_register = shift;
  my $server_dir_full_path = shift;

  my $return_string;
  my $line_counter = 0;
  my %unsuccessful_studies;

  #Remove existing trackhub folders
  foreach my $cell_line (keys %$cell_lines_to_register){
    $line_counter++;
    my $ls_output = `ls $server_dir_full_path`  ;
    my $flag_new_or_update;
    if($ls_output =~/$cell_line/){ # i check if the directory of the study exists already
      $flag_new_or_update = "update";
      my @args = ("rm", "-r", "$server_dir_full_path/$cell_line");
      system(@args) == 0 or die "system @args failed: $?";
    }
  }

  my $track_hub_creator_obj = TrackHubCreation->new($study_id,$server_dir_full_path);


  return (\%unsuccessful_studies);
}


sub print_registry_registered_number_of_th{

  my $registry_obj = shift;

  my $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
  print Dumper($all_track_hubs_in_registry_href); #TODO make print statement that counts distinct trackhubs

}