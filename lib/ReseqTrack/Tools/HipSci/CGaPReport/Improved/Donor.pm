
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::Improved::Donor

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::Improved::Donor;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;
extends 'ReseqTrack::Tools::HipSci::CGaPReport::Donor';

foreach my $attr (qw(gender age ethnicity disease)) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
  );
}

1;
