
package ReseqTrack::Hive::HipSci::FileRelease::Seed;

use strict;

use base ('ReseqTrack::Hive::PipeSeed::ForeignFiles');

sub create_seed_params {
  my ($self) = @_;

  my $options = $self->options;

  $self->SUPER::create_seed_params();

  my @seed_params;
  SEED:
  foreach my $seed_params (@{$self->seed_params}) {
    my ($file, $output_hash) = @$seed_params;
    next SEED if $file->name !~ m{/incoming/keane/};
    push(@seed_params, $seed_params);
  }

  $self->seed_params(\@seed_params);
};

1;
