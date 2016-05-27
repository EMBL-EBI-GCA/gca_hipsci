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

  return bless $self, $class; # this is what makes a reference into an object
}

1;