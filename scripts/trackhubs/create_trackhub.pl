#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciRegistry;  # HipSci specifc version of Registry module of the plantsTrackHubPipeline
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciTrackHubCreation;  # HipSci specifc version of TrackHubCreation module of the plantsTrackHubPipeline

my @exomeseq;  # Data types
my ($server_dir_full_path, $about_url, $hubname, $long_description, $email);
my @assemblies;

GetOptions(
  "server_dir_full_path=s"     => \$server_dir_full_path,
  "hubname=s"                  => \$hubname,
  "long_description=s"         => \$long_description,
  "email=s"                    => \$email,
  "assembly=s"                 => \@assemblies,
  "about_url=s"                => \$about_url,
  "exomeseq=s"                 => \@exomeseq,
);

if(!$server_dir_full_path or !@assemblies or !$hubname){
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

if (!-d $server_dir_full_path) {
  my @args = ("mkdir", "$server_dir_full_path");
  system(@args) == 0 or die "system @args failed: $?";
}

make_THs(\%cell_lines , $server_dir_full_path, $hubname, $long_description, $email, \@assemblies); 

sub make_THs{
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
  }
  
  my $track_hub_creator_obj = HipSciTrackHubCreation->new($cell_lines_to_register, $server_dir_full_path, $hubname, $long_description, $email, $assemblies, $about_url);
  $track_hub_creator_obj->make_track_hub();
}  
  #TODO Need to archive trackhub folder from staging to archive, must also run cleanup archive
