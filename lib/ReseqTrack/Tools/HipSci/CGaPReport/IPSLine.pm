
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::IPSLine

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::IPSLine;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;
use ReseqTrack::Tools::HipSci::CGaPReport::Release;
#use Moose::Util::TypeConstraints;

my %aliases = (
  biosample_id => 'cell_line_biosample_id',
  name => 'lp_cell_line_friendly_name',
  uuid => 'lp_cell_line_sample',
  conjure => 'lp_conjure',
  passage_ips => 'lp_passage_ips',
  split_line => 'lp_split_line',
  qc1 => 'lp_qc1',
  expand => 'lp_expand',
  genomic_assay => 'lp_genomic_assay',
  freeze_ips => 'lp_freeze_ips',
  macs_purify_ips => 'lp_macs_purify_ips',
  freeze_pellet => 'lp_freeze_pellet',
  release_to_kcl => 'lp_release_to_kcl',
  release_to_dundee => 'lp_release_to_dundee',
  release_to_faculty_gaffney => 'lp_release_to_faculty_gaffney',
  sent_for_genotyping => 'lp_sent_for_genotyping',
  cellomics_data_submitted => 'lp_cellomics_data_submitted',
  reasons => 'lp_reasons',
  reprogramming_tech => undef,
  frozen_ips => undef,
  #selected_for_genomics => undef,
  genomics_selection_status => undef,
  #sent_to_genomincs => undef,
  #sent_to_qc1 => undef,
  ips_created => undef,
  #transfer_to_feeder_free => undef,
  ecacc => undef,
);

foreach my $attr (keys %aliases) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
    alias => $aliases{$attr} // [],
  );
}

has 'tissue' => (
  is => 'rw',
  isa => 'ReseqTrack::Tools::HipSci::CGaPReport::Tissue',
);

has 'sequencescape' => (
  is => 'rw',
  isa => 'ArrayRef[ReseqTrack::Tools::HipSci::CGaPReport::SequenceScape]',
  default => sub {[]},
  lazy => 1,
);

has 'release' => (
  is => 'rw',
  isa => 'ArrayRef[ReseqTrack::Tools::HipSci::CGaPReport::Release]',
  default => sub {[]},
  lazy => 1,
);

sub has_values {
  my ($self) = @_;
  return (scalar grep {defined $_} values %$self) ? 1 : 0;
}

my %override_fd_qc1_lines;
foreach my $override_line (qw(HPSI1113i-ieki_2 HPSI0513i-giuf_1 HPSI0913i-bulb_1 HPSI0513i-leeh_3 HPSI0513i-giuf_3 HPSI1113i-ieki_3
          HPSI0713i-aehn_2 HPSI0613i-febc_2 HPSI0413i-iakz_1 HPSI1113i-nibo_3 HPSI1013i-funy_1 HPSI1113i-bima_2 HPSI0813i-iill_3
          HPSI1013i-funy_3 HPSI0813i-iill_1 HPSI0713i-dard_2 HPSI1113i-bima_1 HPSI1113i-qolg_1 HPSI1113i-qolg_3)) {
  $override_fd_qc1_lines{$override_line} = 1;
}

sub BUILD {
  my ($self, $args) = @_;
  return if !$args->{release_type};
  my @types = split(/\|/, $args->{release_type});
  my @goal_times = split(/\|/, $args->{goal_time});
  my @cell_states = split(/\|/, $args->{release_cell_state});
  my @releases;
  foreach my $i (0..$#types) {
    push(@releases, ReseqTrack::Tools::HipSci::CGaPReport::Release->new(type => $types[$i], goal_time => $goal_times[$i], cell_state => $cell_states[$i]));
  }

=cut

  # This is a temporary override and should be removed when lines in LIMs are fixed.
  if ($override_fd_qc1_lines{$self->name}) {
    foreach my $release (@releases) {
      if ($release->is_qc1 && $release->is_feeder_free) {
        $release->cell_state('FD induced pluripotent stem cell');
      }
    }
  }

=cut

  $self->release([sort {$b->goal_time cmp $a->goal_time} @releases]);
}

sub get_release_for {
  my ($self, %args) = @_;
  my ($year, $month, $day) = $args{date} =~ /(\d{4})-?(\d{2})-?(\d{2})/;
  my $date  = sprintf('%s-%s-%s', $year, $month, $day);
  if ($args{type} =~ /qc1/i) {
    my ($release) = sort {$b->goal_time cmp $a->goal_time}
                    grep {$_->is_qc1 && $_->goal_time lt $date}
                    @{$self->release};
    return $release;
  }
  if ($args{type} =~ /qc2/i) {
    my ($release) = sort {$b->goal_time cmp $a->goal_time}
                    grep {$_->is_qc2 && $_->goal_time lt $date}
                    @{$self->release};
    return $release;
  }
}

1;
