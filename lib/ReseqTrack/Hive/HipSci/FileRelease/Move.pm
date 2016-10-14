
package ReseqTrack::Hive::HipSci::FileRelease::Move;

use strict;
use File::Basename qw(fileparse dirname);
use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;

use base ('ReseqTrack::Hive::Process::FileRelease::Move');

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    'derive_path_options' => {
        'free_base_dir' => '/nfs/research2/hipsci/drop/hip-drop/tracked/',
        'controlled_base_dir' => '/nfs/research2/hipsci/controlled/',
        'trim_dir' => '/nfs/research2/hipsci/drop/hip-drop/incoming',
    },
    es_host => 'ves-hx-e4:9200',
  };
}

sub derive_path {
  my ($self, $dropbox_path, $file_object) = @_;

  my $derive_path_options = $self->param('derive_path_options');
  my $controlled_base_dir = $derive_path_options->{controlled_base_dir};
  my $free_base_dir = $derive_path_options->{free_base_dir};
  throw("this module needs a controlled_base_dir") if ! defined $controlled_base_dir;
  throw("this module needs a free_base_dir") if ! defined $free_base_dir;

  my ($filename, $incoming_dirname) = fileparse($dropbox_path);

  throw("pipeline only handles files in /incoming/keane/") if $incoming_dirname !~ m{/incoming/keane/};

  my $destination_base_dir =
          $filename =~ /\.kallisto\.transcripts\.abundance.*\.(?:tsv|h5)/ ? $free_base_dir
        : $incoming_dirname =~ m{/keane/.*/merged_files/} ? $controlled_base_dir
        : $self->derive_destination_base_dir(
              filename =>$filename, 
              controlled_base_dir => $controlled_base_dir,
              free_base_dir => $free_base_dir,
              es => ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $self->param('es_host')),
          );

  my $destination = $self->derive_keane_file(
    filename => $filename,
    destination_base_dir => $destination_base_dir,
    incoming_dirname => $incoming_dirname
  );

  $destination =~ s{//}{/}g;

  #throw(join("\t", $dropbox_path, $destination));
  return $destination;
}

sub derive_destination_base_dir {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $controlled_base_dir = $options{controlled_base_dir} or throw("missing controlled_base_dir");
  my $free_base_dir = $options{free_base_dir} or throw("missing free_base_dir");

  my $cell_line;
  if ($filename =~ /HPSI[0-9]{4}i-[a-z]{4}_[0-9]+/) {
    $cell_line = $options{es}->fetch_line_by_name($&);
  }
  elsif ($filename =~ /HPSI[0-9]{4}[a-z]+-([a-z]{4})/) {
    $cell_line = $options{es}->fetch_line_by_short_name($1);
  }
  throw("did not recognise cell line from $filename") if !$cell_line;
  return $cell_line->{_source}{openAccess} ? $free_base_dir : $controlled_base_dir;
}

sub derive_keane_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");

  my $incoming_dirname = $options{incoming_dirname} or throw("missing incoming_dir_name");
  my ($dirname) = $incoming_dirname =~ m{keane/data/(.*)};
  return "$destination_base_dir/$dirname/$filename";

}


1;
