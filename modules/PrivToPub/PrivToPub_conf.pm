=head1 NAME

 HipSci::PrivToPub::PrivToPub_conf

=head1 SYNOPSIS

=cut


package HipSci::PrivToPub::PrivToPub_conf;

use strict;
use warnings;

use base ('ReseqTrack::Hive::PipeConfig::ReseqTrackGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options() },               # inherit other stuff from the base class

        'pipeline_name' => 'priv_to_pub',                     # name used by the beekeeper to prefix job names on the farm

        seeding_module => 'ReseqTrack::Hive::PipeSeed::BasePipeSeed',
        seeding_options => {
            output_columns => $self->o('file_columns'),
            output_attributes => $self->o('file_attributes'),
            require_columns => $self->o('require_file_columns'),
            exclude_columns => $self->o('exclude_file_columns'),
            require_attributes => $self->o('require_file_attributes'),
            exclude_attributes => $self->o('exclude_file_attributes'),
          },

        file_columns => ['file_id', 'name', 'md5'],
        file_attributes => [],
        require_file_columns => { host_id => [1], type => $self->o('file_types') },
        exclude_file_columns => {},
        require_file_attributes => {},
        exclude_file_attributes => {},
        file_types => [],

        'public_reseqtrack_db'  => {
            -host => $self->o('reseqtrack_db', '-host'),
            -port => $self->o('reseqtrack_db', '-port'),
            -user => $self->o('reseqtrack_db', '-user'),
            -pass => $self->o('reseqtrack_db', '-pass'),
            -dbname => $self->o('public_reseqtrack_db_name'),
        },

    };
}


sub resource_classes {
    my ($self) = @_;
    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '200Mb' => { 'LSF' => '-C0 -M200 -q '.$self->o('lsf_queue').' -R"select[mem>200] rusage[mem=200]"' },
    };
}

sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

    };
}


sub pipeline_analyses {
    my ($self) = @_;

    my @analyses;
    push(@analyses, {
            -logic_name    => 'get_seeds',
            -module        => 'ReseqTrack::Hive::Process::SeedFactory',
            -meadow_type => 'LOCAL',
            -parameters    => {
                seeding_module => $self->o('seeding_module'),
                seeding_options => $self->o('seeding_options'),
            },
            -analysis_capacity  =>  1,  # use per-analysis limiter
            -flow_into => {
                2 => [ 'ascp_file' ],
            },
      });
    push(@analyses, {
            -logic_name    => 'ascp_file',
            -module        => 'HipSci::PrivToPub::ASCP',
            -parameters    => {
              file => '#name#',
              staging_dir => $self->o('staging_dir'),
              remote_trim_dir => $self->o('private_drop_dir'),
              local_trim_dir => $self->o('private_tracked_dir'),
              ascp_user => $self->o('ascp_user'),
              ascp_host => $self->o('ascp_host'),
            },
            -flow_into => {
                1 => { 'store_fastq' => {file => '#file#', md5 => {'#file#' => '#md5#'} }},
            },
            -rc_name => '200Mb',
            -analysis_capacity  =>  25,  # use per-analysis limiter
            -hive_capacity  =>  -1,
      });
    push(@analyses, {
            -logic_name    => 'store_fastq',
            -module        => 'ReseqTrack::Hive::Process::LoadFile',
            -meadow_type => 'LOCAL',
            -parameters    => {
              name_file_module => 'ReseqTrack::Hive::NameFile::BaseNameFile',
              name_file_method => 'default',
              reseqtrack_db => $self->o('public_reseqtrack_db'),
            },
            -flow_into => {
                1 => ['archive_file'],
            },
      });
    push(@analyses, {
            -logic_name    => 'archive_file',
            -module        => 'HipSci::PrivToPub::Archive',
            -meadow_type => 'LOCAL',
            -parameters    => {
              reseqtrack_db => $self->o('public_reseqtrack_db'),
            },
            -flow_into => {
                1 => ['mark_seed_complete'],
            },
            -analysis_capacity  =>  1,
      });
    push(@analyses, {
            -logic_name    => 'mark_seed_complete',
            -module        => 'ReseqTrack::Hive::Process::UpdateSeed',
            -parameters    => {
              is_complete  => 1,
            },
            -meadow_type => 'LOCAL',
      });

    return \@analyses;
}

1;

