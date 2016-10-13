
package ReseqTrack::Hive::HipSci::FileRelease::Checks;
use strict;

use base ('ReseqTrack::Hive::Process::FileRelease::Checks');

sub get_check_subs {
  my ($self) = @_;
  return {quick => [map {$self->can($_)} qw(check_ctime check_update_time check_size check_name)],
          slow =>  [map {$self->can($_)} qw(check_ctime check_update_time check_md5)]};
}


# continue adding to this:
sub check_name {
  my ($self, $dropbox_path, $file_object) = @_;
  my ($filename, $incoming_dirname) = fileparse($dropbox_path);
  if ($incoming_dirname =~ m{/incoming/keane}) {
    if ($filename !~ /([\._])20\d{6}((\g{1})|\.)/) {
      $self->is_reject(1);
      $self->reject_message("file does not contain a date");
      return 0;
    }
  }
  return 1;
}

1;
