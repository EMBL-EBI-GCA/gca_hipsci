
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;
extends 'ReseqTrack::Tools::HipSci::CGaPReport::IPSLine';

foreach my $attr (qw(growing_conditions)) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
  );
}

1;
