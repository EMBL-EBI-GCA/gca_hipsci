package ReseqTrack::Tools::HipSci::OverrideSelectedStatus;
use MooseX::Singleton;
use File::Basename;
use namespace::autoclean;

has hash => (
  is => 'ro',
  isa => 'HashRef',
  builder => '_build_hash',
);

sub _build_hash {
  my ($self) = @_;
  my $path_of_this_module = File::Basename::dirname( eval { ( caller() )[1] } );
  my %lines;
  my $filename = "$path_of_this_module/../../../../tracking_resources/override_selected_status.tsv";
  open my $fh, '<', $filename or die $!;
  while (my $line = <$fh>) {
    next if $line =~ /^#/;
    chomp $line;
    my ($line) = split("\t", $line);
    next if !$line;
    $lines{$line} = 1;
  }
  close $fh;
  return \%lines;
}

sub is_overridden {
  my ($self, $line) = @_;
  return $self->hash->{$line} ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;
