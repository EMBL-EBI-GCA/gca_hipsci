
package ReseqTrack::Hive::HipSci::PrivToPub::Archive;

use strict;

use base ('ReseqTrack::Hive::Process::BaseProcess');
use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::Tools::Loader::Archive;

sub param_defaults {
  return {
  };
}

sub run {
    my $self = shift @_;

    $self->param_required('file');
    my $file = $self->param_as_array('file');
    my $db_params = $self->param_required('reseqtrack_db');

    my $archiver = ReseqTrack::Tools::Loader::Archive->new(
      -file => $file, 
      -dbuser => $db_params->{-user},
      -dbpass => $db_params->{-pass},
      -dbhost => $db_params->{-host},
      -dbname => $db_params->{-dbname},
      -dbport => $db_params->{-port},
      -action => 'archive',
      -priority => 99,
    );

    $archiver->process_input();
    $archiver->sanity_check_objects();
    $archiver->archive_objects();

}

1;

