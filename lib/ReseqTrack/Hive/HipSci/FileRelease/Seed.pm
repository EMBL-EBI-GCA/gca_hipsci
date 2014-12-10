
package ReseqTrack::Hive::HipSci::FileRelease::Seed;

use strict;
use ReseqTrack::Tools::FileSystemUtils qw(get_lines_from_file);
use File::Basename qw( fileparse );

use base ('ReseqTrack::Hive::PipeSeed::ForeignFiles');

sub create_seed_params {
  my ($self) = @_;

  my $options = $self->options;
  my $dundee_conversion_file = $options->{'dundee_conversion_file'} or throw("no dundee_conversion_fie");
  open my $IN, '<', $dundee_conversion_file or throw("could not open $dundee_conversion_file $_");
  my %dundee_conversions;
  while (my $line = <$IN>) {
    chomp $line;
    my ($cell_line, $dundee_ids) = split("\t", $line);
    my $replicate = 0;
    ID:
    foreach my $dundee_id (split(/;\s*/, $line)) {
      my ($ID, $num_parts) = $dundee_id =~ /PTSS(\d+)\s*\((\d+)\)/;
      next ID if !$ID;
      $replicate += 1;
      $dundee_conversions{$ID} = {cell_line => $cell_line, num_parts => $num_parts, replicate => $replicate};
    }
  }
  close $IN;

  my $biosamples_file = $options->{'biosamples_file'} or throw("no biosamples_file");
  my %cell_line_name_map;
  open $IN, '<', $biosamples_file or throw("could not open $biosamples_file $_");
  my $found_SCD = 0;
  CELL_LINE:
  while (my $line = <$IN>) {
    if (!$found_SCD) {
      $found_SCD = $line =~ /^\[SCD\]/;
      <$IN> if $found_SCD;
      next CELL_LINE;
    }
    my $cell_line_name = (split("\t", $line))[2];
    next CELL_LINE if !$cell_line_name;
    my ($friendly_name) = $cell_line_name =~ /([a-z]{4}(?:_\d+)?)$/;
    next CELL_LINE if !$friendly_name;
    $cell_line_name_map{$friendly_name} = $cell_line_name;

  }
  close $IN;

  $self->SUPER::create_seed_params();

  my @seed_params;
  foreach my $seed_params (@{$self->seed_params}) {
    my ($file, $output_hash) = @$seed_params;
    my $path = $file->name;
    if ($path =~ m{/lamond/.*raw$} || $path =~ m{/stegle/.*featureXML}) {
      my $filename = fileparse($path);
      my ($dundee_id) = $filename =~ /^PT(?:SS)?(\d+)/;
      push(@{$dundee_conversions{$dundee_id}->{seed_params}}, $seed_params);
    }
    else {
      push(@seed_params, $seed_params);
    }
  }

  CELL_LINE:
  while (my ($dundee_id, $dundee_hash) = each %dundee_conversions) {
    next CELL_LINE if !$dundee_hash->{seed_params};
    next CELL_LINE if $dundee_hash->{num_parts} != scalar @{$dundee_hash->{seed_params}};
    throw("unexpected number of proteomics files") if ! grep {$dundee_hash->{num_parts} == $_} (16, 23);
    my $part_num = 0;
    foreach my $seed_params (sort @{$dundee_hash->{seed_params}}) {
      $part_num += 1;
      $seed_params->[1]->{file}->{part_num} = $part_num;
      $seed_params->[1]->{file}->{cell_line} = $cell_line_name_map{$dundee_hash->{cell_line}};
      $seed_params->[1]->{file}->{replicate} = $dundee_hash->{replicate};
      $seed_params->[1]->{file}->{frac_method} = $dundee_hash->{num_parts} == 16 ? 'sax' : 'hilic';
      push(@seed_params, $seed_params);
    }
  }


  $self->seed_params(\@seed_params);
};

1;
