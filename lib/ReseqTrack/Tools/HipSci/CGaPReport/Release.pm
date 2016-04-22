
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::Release

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::Release;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;

has 'ips_line' => (
  is => 'rw',
  isa => 'ReseqTrack::Tools::HipSci::CGaPReport::IPSLine',
);

foreach my $has (qw(type goal_time cell_state passage)) {
  has $has => (
      is => 'rw',
      isa => 'Maybe[Str]',
  );
}

sub is_feeder_free {
  my ($self) = @_;
  return $self->cell_state =~ /^FF/ ? 1
        : $self->cell_state =~ /^FD/ ? 0
        : $self->cell_state =~ /TRA-1-60/ ? 0
        : die 'did not recognise cell state '.$self->cell_state;
}

sub is_qc1 {
  my ($self) = @_;
  return $self->type =~ /CoreEx/ ? 1
        : $self->type =~ /MicroArray/ ? 1
        : 0;
}

sub is_qc2 {
  my ($self) = @_;
  return $self->type =~ /Methyl/ ? 1
        : $self->type =~ /RNASeq/ ? 1
        : $self->type =~ /WES/ ? 1
        : 0;
}


1;
