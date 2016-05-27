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
  my $assemblies = shift;

  $self->make_study_dir($server_dir_full_path, $study_id);
  $self->make_assemblies_dirs($server_dir_full_path, $study_id, $assemblies);

  $self->make_hubtxt_file($server_dir_full_path, $study_id);
  $self->make_genomestxt_file($server_dir_full_path, $study_id);
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

sub make_study_dir{

  my $self= shift;
  my $server_dir_full_path= shift;
  my $study_id = shift;

  run_system_command("mkdir $server_dir_full_path" . '/' . $study_id)
    or die "I cannot make dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
}

sub make_assemblies_dirs{

  my $self= shift;
  my $server_dir_full_path= shift;
  my $study_id = shift;
  my $assemblies = shift;

  foreach my $assembly (@$assemblies){

    run_system_command("mkdir $server_dir_full_path/$study_id/$assembly")
      or die "I cannot make directories of assemblies in $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
  }
}

sub make_hubtxt_file{

  my $self= shift;
  my $server_dir_full_path= shift;
  my $study_id = shift;
  my $hub_txt_file= "$server_dir_full_path/$study_id/hub.txt";

  run_system_command("touch $hub_txt_file")
    or die "Could not create hub.txt file in the $server_dir_full_path location\n";
  
  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $! in ".__FILE__." line: ".__LINE__."\n";

  print $fh "hub $study_id\n";

  print $fh "shortLabel "."HipSci TrackHub for ".$study_id."\n"; 
  #TODO Check what to display on long label
  print $fh "longLabel "."Human Induced Pluripotent Stem Cells Initiative (HipSci) TrackHub for HipSci cell line ".$study_id."\n"; 
  print $fh "genomesFile genomes.txt\n";
  print $fh "email hipsci-dcc\@ebi.ac.uk\n";
  close($fh);
}

sub make_genomestxt_file{
  my $self= shift;
  my $server_dir_full_path= shift;
  my $study_id = shift;
  my $assembly_names_href = $study_obj->get_assembly_names;

  my $genomes_txt_file = "$server_dir_full_path/$study_id/genomes.txt";

  run_system_command("touch $genomes_txt_file")
    or die "Could not create genomes.txt file in the $server_dir_full_path location\n";

  open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!\n";

  foreach my $assembly_name (keys %{$assembly_names_href}) {

    print $fh2 "genome ".$assembly_name."\n"; 
    print $fh2 "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
  }

}

1;