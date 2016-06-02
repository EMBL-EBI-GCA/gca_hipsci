package HipSciTrackHubCreation;

#HipSci specifc version of TrackHubCreation module of the plantsTrackHubPipeline (https://github.com/EnsemblGenomes/plantsTrackHubPipeline)

use strict;
use warnings;
use POSIX qw(strftime);
use ReseqTrack::Tools::HipSci::TrackHubs::HipSciSuperTrack;
use Data::Dumper;

sub new {

  my $class = shift;
  my $cell_lines  = shift; 
  my $server_dir_full_path = shift;
  my $hubname = shift;
  my $long_description = shift;
  my $email = shift;
  my $assemblies = shift;
  my $about_url = shift;
  
  defined $cell_lines and defined $server_dir_full_path and defined $assemblies
    or die "Object must be constructed using 2 parameters: study id and folder path\n";

  my $self = {
    cell_lines        => $cell_lines,
    trackhubpath      => $server_dir_full_path.'/'.$hubname,
    hubname           => $hubname,
    long_description  => $long_description,
    email             => $email,
    assemblies        => $assemblies,
    about_url         => $about_url
  };

  return bless $self, $class;
}

sub make_track_hub{ # main method, creates the track hub of a study in the folder/server specified

  my $self= shift;
  my $cell_lines = $self->{cell_lines};
  my $trackhubpath = $self->{trackhubpath};
  my $hubname = $self->{hubname};
  my $long_description = $self->{long_description};
  my $email = $self->{email};
  my $assemblies = $self->{assemblies};
  my $about_url = $self->{about_url};
  

  $self->make_study_dir($trackhubpath);
  $self->make_assemblies_dirs($trackhubpath, $assemblies);

  $self->make_hubtxt_file($trackhubpath, $hubname, $long_description, $email, $about_url);
  $self->make_genomestxt_file($trackhubpath, $assemblies);

  foreach my $assembly (@$assemblies){
    $self->make_trackDbtxt_file($trackhubpath, $assembly, $cell_lines);
  }
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
  my $trackhubpath= shift;

  run_system_command("mkdir $trackhubpath")
    or die "I cannot make dir $trackhubpath in script: ".__FILE__." line: ".__LINE__."\n";
}

sub make_assemblies_dirs{

  my $self= shift;
  my $trackhubpath= shift;
  my $assemblies = shift;

  foreach my $assembly (@$assemblies){

    run_system_command("mkdir $trackhubpath/$assembly")
      or die "I cannot make directories of assemblies in $trackhubpath in script: ".__FILE__." line: ".__LINE__."\n";
  }
}

sub make_hubtxt_file{

  my $self = shift;
  my $trackhubpath = shift;
  my $hubname = shift;
  my $long_description = shift;
  my $email = shift;
  my $about_url = shift;
  my $hub_txt_file = "$trackhubpath/hub.txt";

  my $date = strftime "%Y_%m_%d", localtime;

  run_system_command("touch $hub_txt_file")
    or die "Could not create hub.txt file in the $hub_txt_file location\n";
  
  open(my $fh, '>', $hub_txt_file) or die "Could not open file '$hub_txt_file' $! in ".__FILE__." line: ".__LINE__."\n";

  print $fh "hub ".$hubname."_".$date."\n";

  print $fh "shortLabel ".$hubname."\n"; 
  print $fh "longLabel ".$long_description."\n";
  print $fh "genomesFile genomes.txt\n";
  print $fh "email ".$email."\n";
  if (defined $about_url){
    print $fh "descriptionUrl ".$about_url."\n";
  }
  close($fh);
}

sub make_genomestxt_file{
  my $self= shift;
  my $trackhubpath= shift;
  my $assemblies = shift;

  my $genomes_txt_file = "$trackhubpath/genomes.txt";

  run_system_command("touch $genomes_txt_file")
    or die "Could not create genomes.txt file in the $trackhubpath location\n";

  open(my $fh2, '>', $genomes_txt_file) or die "Could not open file '$genomes_txt_file' $!\n";

  foreach my $assembly (@$assemblies){

    print $fh2 "genome ".$assembly."\n"; 
    print $fh2 "trackDb ".$assembly."/trackDb.txt"."\n\n"; 
  }
}

sub make_trackDbtxt_file{
  my $self =shift;
  my $trackhubpath = shift;
  my $assembly = shift;
  my $cell_lines = shift;

  my $trackDb_txt_file="$trackhubpath/$assembly/trackDb.txt";

  run_system_command("touch $trackDb_txt_file")
    or die "Could not create trackDb.txt file in the $trackhubpath/$assembly location\n";       

  open(my $fh, '>', $trackDb_txt_file)
    or die "Error in ".__FILE__." line ".__LINE__." Could not open file '$trackDb_txt_file' $!";

  my $counter_of_tracks=0;
  foreach my $cell_line (keys %$cell_lines){
    my $super_track_obj = $self->make_biosample_super_track_obj($cell_line, $$cell_lines{$cell_line});
    $super_track_obj->print_track_stanza($fh);

    my $visibility="off";

    #foreach my $track ($$cell_lines{$cell_line}{data}){
    #  print Dumper($track);
    #}
  }
  
  

  #foreach my $track (@$data){
    #print Dumper($track)
    # $counter_of_tracks++;
    # if ($counter_of_tracks <=10){
    #     $visibility = "on";
    # }else{
    #     $visibility = "off";
    # }
    # my $track_obj=$self->make_biosample_sub_track_obj($study_obj,$biorep_id,$sample_id,$visibility);
    # $track_obj->print_track_stanza($fh);
  #}
}

sub make_biosample_super_track_obj{
  my $self= shift;
  my $cell_line = shift;
  my $data = shift;

  my $long_label = $cell_line." BioSample ID: ".$$data{biosample_id};

  my $date_string = strftime "%a %b %e %H:%M:%S %Y %Z", gmtime;  # date is of this type: "Tue Feb  2 17:57:14 2016 GMT"
  my $metadata_string="hub_created_date=".printlabel_value($date_string)." biosample_id=".$$data{biosample_id}." sample_alias=".$cell_line;

  my $super_track_obj = HipSciSuperTrack->new($cell_line,$long_label,$metadata_string);
  return $super_track_obj;
}

# i want they key of the key-value pair of the metadata to have "_" instead of space if they are more than 1 word
sub printlabel_key {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
    $string =~ s/ /_/g;

  }
  return $string;
}

# I want the value of the key-value pair of the metadata to have quotes in the whole string if the value is more than 1 word.
sub printlabel_value {

  my $string = shift ;
  my @array = split (/ /,$string) ;

  if (scalar @array > 1) {
       
    $string = "\"".$string."\"";  

  }
  return $string;
}

1;