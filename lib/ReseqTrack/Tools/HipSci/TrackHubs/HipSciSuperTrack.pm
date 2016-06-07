package HipSciSuperTrack;

use strict;
use warnings;

sub new {

  my $class = shift;
  my $track_name = shift;
  my $long_label = shift;
  my $metadata = shift;

  defined $track_name and $long_label and $metadata
    or die "Some required parameters are missing in the constructor of the SuperTrack\n";

  my $self = {
    track_name => $track_name,
    long_label => $long_label,
    metadata => $metadata,
  };

  return bless $self, $class; # this is what makes a reference into an object
}

sub print_track_stanza{

  my $self = shift;
  my $fh = shift;
  my $counter_of_tracks = shift;

  print $fh "track ". $self->{track_name}."\n"; 
  if ($counter_of_tracks <=10){
    print $fh "superTrack on show\n";
  }else{
    print $fh "superTrack on hide\n";
  }
  print $fh "shortLabel ".$self->{track_name}."\n";
  print $fh "longLabel ".$self->{long_label}."\n";
  print $fh "metadata ".$self->{metadata}."\n";
  print $fh "\n";

}


1;