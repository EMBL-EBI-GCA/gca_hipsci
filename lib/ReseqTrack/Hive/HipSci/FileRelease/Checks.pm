
package ReseqTrack::Hive::HipSci::FileRelease::Checks;
use strict;
use File::Basename qw(fileparse);

use base ('ReseqTrack::Hive::Process::FileRelease::Checks');

sub get_check_subs {
  my ($self) = @_;
  return {quick => [map {$self->can($_)} qw(check_ctime check_update_time check_size check_name check_lamond_id)],
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

sub check_lamond_id {
  my ($self, $dropbox_path, $file_object) = @_;
  if ($dropbox_path =~ m{/lamond/.*\.raw$} || $dropbox_path =~ m{/lamond/.*\.mzML$}) {
    my $file_details = $self->param('file');
    my $cell_line_name = $file_details->{'cell_line'};
    if (!$cell_line_name) {
        $self->is_reject(1);
        $self->reject_message("unrecognized peptracker id");
        return 0;
    }
  }
  return 1;
}

1;
