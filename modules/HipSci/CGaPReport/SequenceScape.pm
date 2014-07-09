
=pod

=head1 NAME

HipSci::CGaPReport::SequenceScape

=cut

package HipSci::CGaPReport::SequenceScape;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;

my %aliases = (
  internal_id => 'ss_internal_id',
  sample_name => 'ss_sample_name',
  gender => 'ss_gender',
  origin => 'ss_origin',
  date_created => 'ss_date_created',
  sanger_sample_id => 'ss_sanger_sample_id',
  control => 'ss_control',
  sample_visibility => 'ss_sample_visibility',
);

my %types = (
  control => 'Maybe[Bool]',
);

foreach my $attr (keys %aliases) {
  has $attr => (
    is => 'rw',
    isa => $types{$attr} // 'Maybe[Str]',
    alias => $aliases{$attr} // [],
  );
}

has 'ips_line' => (
  is => 'rw',
  isa => 'HipSci::CGaPReport::IPSLine',
);

sub has_values {
  my ($self) = @_;
  return (scalar grep {defined $_} values %$self) ? 1 : 0;
}


1;
