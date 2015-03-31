
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine;
use DateTime;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;
extends 'ReseqTrack::Tools::HipSci::CGaPReport::IPSLine';

foreach my $attr (qw(growing_conditions_qc1 growing_conditions_qc2)) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
  );
}

has 'is_transferred' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    builder => '_build_is_transferred',
    lazy => 1,
  );

sub _build_is_transferred {
  my ($self) = @_;
  my $transitioned = $self->transfer_to_feeder_free;
  my $qc1 = $self->qc1;
  return undef if !$transitioned || !$qc1;
  my ($trans_year, $trans_mon, $trans_day) = $transitioned =~ /(\d+)-(\d+)-(\d+)/;
  my ($qc1_year, $qc1_mon, $qc1_day) = $qc1 =~ /(\d+)-(\d+)-(\d+)/;
  my $trans_dt = DateTime->new(year=>$trans_year, month=>$trans_mon, day=>$trans_day);
  my $qc1_dt = DateTime->new(year=>$qc1_year, month=>$qc1_mon, day=>$qc1_day);
  return (DateTime->compare($trans_dt, $qc1_dt) == 1) ? 1 : 0;
}

1;
