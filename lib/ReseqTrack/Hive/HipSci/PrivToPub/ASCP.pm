
package ReseqTrack::Hive::HipSci::PrivToPub::ASCP;

use strict;

use base ('ReseqTrack::Hive::Process::BaseProcess');
use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::Tools::GeneralUtils qw(execute_system_command);
use ReseqTrack::Tools::FileSystemUtils qw(check_directory_exists);
use Env qw($ASPERA_SCP_PASS);
use File::Basename qw(dirname);


sub param_defaults {
  return {
    ascp => 'ascp',
    ascp_user => 'hip-drop',
    ascp_host => 'ah01.ebi.ac.uk',
  };
}

sub run {
    my $self = shift @_;

    throw("ascp password is not set") if !$ASPERA_SCP_PASS;

    my $file = $self->param_required('file');
    my $ascp = $self->param_required('ascp');
    my $staging_dir = $self->param_required('staging_dir');
    my $remote_trim_dir = $self->param_required('remote_trim_dir');
    my $local_trim_dir = $self->param_required('local_trim_dir');
    my $ascp_user = $self->param_required('ascp_user');
    my $ascp_host = $self->param_required('ascp_host');

    my $output_path = $file;
    $output_path =~ s/^$local_trim_dir// or throw("could not trim $file $local_trim_dir");
    $output_path = "$staging_dir/$output_path";
    $output_path =~ s{//}{/}g;
    my $output_dir = dirname($output_path);
    check_directory_exists($output_dir);

    my $remote_path = $file;
    $remote_path =~ s/^$remote_trim_dir// or throw("could not trim $file $remote_trim_dir");
    $remote_path =~ s{//}{/}g;

    my $cmd = sprintf("%s -k2 -T -Q -l 100M '%s@%s:%s' '%s'", $ascp, $ascp_user, $ascp_host, $file, $output_path);
    $self->dbc->disconnect_when_inactive(1);
    my $return = eval{execute_system_command($cmd);};
    my $msg_thrown = $@;
    $self->dbc->disconnect_when_inactive(0);
    die "$msg_thrown" if $msg_thrown;

    $self->output_param('file', $output_path);

}

1;

