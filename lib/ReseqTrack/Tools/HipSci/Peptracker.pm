use List::Util qw();
use List::MoreUtils qw();
use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(exp_design_to_pep_ids pep_id_to_tmt_lines);

sub exp_design_to_pep_ids {
  my ($file) = @_;
  my %pep_ids;
  open my $fh, '<', $file or die $!;
  <$fh>;
  while (my $line = <$fh>) {
    $line =~ s/\R//g;
    $pep_ids{(split('\t', $line))[2]} = 1;
  }
  return [keys %pep_ids];
}

sub pep_id_to_tmt_lines {
  my ($pep_id, $peptracker_obj) = @_;
  $pep_id =~ s/^PT//;
  my $sample_set = List::Util::first {$_->{id} == $pep_id} @{$peptracker_obj->{sample_sets}};
  die "did not get sample group for $pep_id" if !$sample_set;
  my $sample_group = $sample_set->{sample_groups}[0];

  my %tmt_index;
  while (my ($index, $details) = each @{$sample_group->{details}{tmt_details}}) {
    $details->{details} =~ /^(HPSI[0-9]{4}i-)?([A-Za-z]{4}_[0-9]+)/;
    die "did not recognise name $details->{details}" if !$2;
    $tmt_index{lc($2)} = $index;
  }
  
  my @cell_lines;
  foreach my $sample (@{$sample_group->{details}{ips_cells}}) {
    $sample->{name} =~ /HPSI[0-9]{4}i-([a-z]{4}_[0-9]+)/;
    my $ips_name = $& or die "did not recognize HipSci name $sample->{name}";
    my $short_name = $1;
    die "did not find tmt details for $short_name" if ! exists $tmt_index{$short_name};
    $cell_lines[$tmt_index{$short_name}] = $ips_name;
  }
  return \@cell_lines;
}

1;
