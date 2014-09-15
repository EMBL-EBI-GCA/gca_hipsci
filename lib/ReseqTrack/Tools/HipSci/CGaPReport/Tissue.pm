
=pod

=head1 NAME

ReseqTrack::Tools::HipSci::CGaPReport::Tissue

=cut

package ReseqTrack::Tools::HipSci::CGaPReport::Tissue;
use namespace::autoclean;
use Moose;
use MooseX::Aliases;

my %aliases = (
  biosample_id => 'fibroblast_biosample_id',
  uuid => 'dp_cell_line_sample',
  name => 'dp_cell_line_friendly_name',
  registration => 'dp_registration',
  conjure => 'dp_conjure',
  check_mycoplasma_result => 'dp_check_mycoplasma_result',
  observed_outgrowths => 'dp_observed_outgrowths',
  observed_fibroblasts => 'dp_observed_fibroblasts',
  passage_primary_fibroblast => 'dp_passage_primary_firbroblast',
  freeze_primary_fibroblast => 'dp_freeze_primary_firbroblast',
  colony_picking => 'dp_colony_picking',
  passage_ips => 'dp_passage_ips',
  qc1 => 'dp_qc1',
  reasons => 'dp_reasons',
  type => 'tissue_type',
);

foreach my $attr (keys %aliases) {
  has $attr => (
    is => 'rw',
    isa => 'Maybe[Str]',
    alias => $aliases{$attr} // [],
  );
}


has 'ips_lines' => (
  is => 'rw',
  isa => 'ArrayRef[ReseqTrack::Tools::HipSci::CGaPReport::IPSLine]',
  default => sub {[]},
  lazy => 1,
);

has 'donor' => (
  is => 'rw',
  isa => 'ReseqTrack::Tools::HipSci::CGaPReport::Donor',
);

sub has_values {
  my ($self) = @_;
  return (scalar grep {defined $_} values %$self) ? 1 : 0;
}

1;
