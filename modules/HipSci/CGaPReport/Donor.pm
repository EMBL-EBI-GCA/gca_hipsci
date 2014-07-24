
=pod

=head1 NAME

HipSci::CGaPReport::Donor

=cut

package HipSci::CGaPReport::Donor;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;

my %aliases = (
  biosample_id => 'donor_biosample_id',
  uuid => 'dp_donor_cohort',
  hmdmc => 'dp_approval_number',
  supplier_name => undef,
);

foreach my $attr (keys %aliases) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
    alias => $aliases{$attr} // [],
  );
}

has 'tissues' => (
  is => 'rw',
  isa => 'ArrayRef[HipSci::CGaPReport::Tissue]',
  default => sub {[]},
  lazy => 1,
);

sub has_values {
  my ($self) = @_;
  return (scalar grep {defined $_} values %$self) ? 1 : 0;
}

1;
