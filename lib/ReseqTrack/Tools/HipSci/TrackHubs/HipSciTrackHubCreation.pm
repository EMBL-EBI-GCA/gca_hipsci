package HipSciTrackHubCreation;

#HipSci specifc version of TrackHubCreation module of the plantsTrackHubPipeline (https://github.com/EnsemblGenomes/plantsTrackHubPipeline)

use strict;
use warnings;

sub new {

  my $class = shift;
  my $study_id  = shift; 
  my $server_dir_full_path = shift;
  
  defined $study_id and defined $server_dir_full_path
    or die "Object must be constructed using 2 parameters: study id and folder path\n";

  my $self = {
    study_id  => $study_id ,
    server_dir_full_path => $server_dir_full_path
  };

  return bless $self, $class;
}

sub make_track_hub{ # main method, creates the track hub of a study in the folder/server specified

  my $self= shift;
  my $study_id= $self->{study_id};
  my $server_dir_full_path = $self->{server_dir_full_path};
  my $data = shift;

  $self->make_study_dir($server_dir_full_path, $study_id);
}

sub make_study_dir{

  my $self= shift;
  my $server_dir_full_path= shift;
  my $study_id = shift;

  run_system_command("mkdir $server_dir_full_path" . '/' . $study_id)
    or die "I cannot make dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
}

sub run_system_command {

  my $command = shift;

  `$command`;

  if($? !=0){ # if exit code of the system command is successful returns 0
    return 0; 

  }else{
     return 1;
  }
}

1;