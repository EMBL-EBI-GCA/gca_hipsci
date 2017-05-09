package ReseqTrack::Tools::HipSci::QC1Samples;
use MooseX::Singleton;
use File::Basename;
use File::Find qw(find);
use namespace::autoclean;

has pluritest_file => ( is => 'rw', isa => 'Str', lazy_build => 1);
has cnv_summary_file => ( is => 'rw', isa => 'Str', lazy_build => 1);
has qc1_directory => (is => 'rw', isa => 'Str', default => '/nfs/research2/hipsci/drop/hip-drop/tracked/qc1_raw_data/');
has gtarray_samples => (is => 'ro', isa => 'HashRef', lazy_build => 1);
has gexarray_samples => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub is_valid_gtarray {
  my ($self, $cell_line, $sample) = @_;
  my $allowed_samples = $self->gtarray_samples();
  return $allowed_samples->{$cell_line} && $allowed_samples->{$cell_line} eq $sample ? 1 : 0;
}

sub is_valid_gexarray {
  my ($self, $cell_line, $sample) = @_;
  my $allowed_samples = $self->gexarray_samples();
  return $allowed_samples->{$cell_line} && $allowed_samples->{$cell_line} eq $sample ? 1 : 0;
}

sub _build_pluritest_file {
  my ($self) = @_;
  return $self->_build_file('pluritest');
}

sub _build_cnv_summary_file {
  my ($self) = @_;
  return $self->_build_file('cnv_summary');
}

sub _build_file {
  my ($self, $type) = @_;
  my $file_date;
  my $pluritest_file;
  find(sub {
    return if ! -f $_;
    return if ! /hipsci.qc1.(\d+).$type.tsv/;
    return if $file_date && $file_date > $1;
    $file_date = $1;
    $pluritest_file = $File::Find::name;
  }, $self->qc1_directory);
  return $pluritest_file;
}

sub _build_gtarray_samples {
  my ($self) = @_;
  return $self->_build_sample_hash($self->cnv_summary_file(), $self->pluritest_file());
}

sub _build_gexarray_samples {
  my ($self) = @_;
  return $self->_build_sample_hash($self->pluritest_file(), $self->cnv_summary_file());
}

sub _build_sample_hash {
  my ($self, $target_file, $other_file) = @_;
  my %other_assay_samples;
  open my $fh1, '<', $other_file or die $!;
  <$fh1>;
  while (my $line = <$fh1>) {
    chomp $line;
    my ($sample) = split("\t", $line);
    next if $sample !~ /(HPSI\w+-[a-z]{4}(?:_\d+)?)_(.+)/;
    $other_assay_samples{$1} = $2;
  }
  close $fh1;

  my %allowed_samples;
  open my $fh2, '<', $target_file or die $!;
  <$fh2>;
  while (my $line = <$fh2>) {
    chomp $line;
    my ($sample) = split("\t", $line);
    next if $sample !~ /(HPSI\w+-[a-z]{4}(?:_\d+)?)_(.+)/;
    my ($cell_line, $qc_sample) = ($1, $2);
    next if $allowed_samples{$cell_line} && $allowed_samples{$cell_line} eq $qc_sample;
    $allowed_samples{$cell_line} = $qc_sample;
  }
  close $fh2;
  return \%allowed_samples;
}

__PACKAGE__->meta->make_immutable;

1;
