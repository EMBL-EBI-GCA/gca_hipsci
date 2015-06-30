#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use List::Util qw();
use Getopt::Long;
use File::Basename qw(fileparse);
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Copy qw(copy);

my $output_prefix = 'hipsci.qc1';
my $plot_directory;
GetOptions(
          'output_prefix=s' => \$output_prefix,
          'plot_directory=s' => \$plot_directory,
          );

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
$ua->default_header('Content-Type' => 'application/json');
my $json = JSON->new->allow_nonref;

my $response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Group'}),
  );
my $groups = $json->decode($response->content);
my $hipsci_group_id = (List::Util::first {$_->{properties}->{name} eq 'hipsci'} @$groups)->{id};

$hipsci_group_id+=0; # force it to be interpreted as a number
$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Study', groups => $hipsci_group_id}),
  );
my $studies = $json->decode($response->content);
my %study_ids = map {($_->{id} => 1)} @$studies;

$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Donor', studies => join(',', keys %study_ids)}),
  );
my $donors = $json->decode($response->content);

open my $gender_fh, '>', $output_prefix.'.gender.tsv' or die "could not open $output_prefix $!";
open my $discordance_genotyping_fh, '>', $output_prefix.'.discordance_genotyping.tsv' or die "could not open $output_prefix $!";
open my $discordance_fluidigm_fh, '>', $output_prefix.'.discordance_fluidigm.tsv' or die "could not open $output_prefix $!";
open my $pluritest_fh, '>', $output_prefix.'.pluritest.tsv' or die "could not open $output_prefix $!";
open my $cnv_fh, '>', $output_prefix.'.cnv_summary.tsv' or die "could not open $output_prefix $!";
open my $cnv_aberrant_region_fh, '>', $output_prefix.'.cnv_aberrant_region.tsv' or die "could not open $output_prefix $!";
open my $cnv_polysomy_fh, '>', $output_prefix.'.cnv_polysomy.tsv' or die "could not open $output_prefix $!";
open my $loh_fh, '>', $output_prefix.'.loh.tsv' or die "could not open $output_prefix $!";

print $gender_fh join("\t", qw(sample_public_name sample_name expected_gender actual_gender)), "\n";
print $discordance_genotyping_fh join("\t", qw(sample1 sample2 sample1_is_control sample2_is_control discordance num_of_sites avg_min_depth)), "\n";
print $discordance_fluidigm_fh join("\t", qw(sample1 sample2 sample1_is_control sample2_is_control discordance num_of_sites avg_min_depth)), "\n";
print $pluritest_fh join("\t", qw(sample pluri_raw pluri_logit_p novelty novelty_logit_p rmsd)), "\n";
print $cnv_fh join("\t", qw(sample num_different_regions length_different_regions_Mbp length_shared_differences_Mbp)), "\n";
print $cnv_aberrant_region_fh join("\t", qw(sample copy_number chromosome start end length quality)), "\n";
print $cnv_polysomy_fh join("\t", qw(sample chromosome)), "\n";
print $loh_fh join("\t", qw(control_sample sample chromosome start end count)), "\n";

foreach my $donor_id (map {$_->{id}} @$donors) {
  $donor_id += 0; # forces it to be treated as a number in the json encoding
  ATTEMPT:
  foreach my $attempt (1..5) {
    $response = $ua->post('https://localhost:9090/rest/qc/donor_qc',
        Content => $json->encode({donor => $donor_id}),
      );
    last ATTEMPT if !$response->is_error;
    die $response->status_line if $attempt == 5;
    sleep(10);
  }
  my $donor_qc = $json->decode($response->content);

  my $donor_name;
  QC:
  foreach my $qc (@$donor_qc) {
    my $sample_name = $qc->{sample} || $qc->{sample_public_name} || $qc->{sample1_public_name};
    next QC if !$sample_name;
    my ($donor_name_part1, $donor_name_part2) = $sample_name =~ /^(\w+\d+)\w+-([a-z]+)/;
    next QC if !$donor_name_part1;
    $donor_name = $donor_name_part1 . '-' . $donor_name_part2;
    last QC;
  }
  exit if !$donor_name;

  QC:
  foreach my $gender_qc (grep {$_->{type} eq 'gender'} @$donor_qc) {
    next QC if !$gender_qc->{sample_public_name};
    print $gender_fh join("\t", @{$gender_qc}{qw(sample_public_name sample_name expected_gender actual_gender)}), "\n";
  }
  QC:
  foreach my $discordance_qc (grep {$_->{type} eq 'discordance_genotyping'} @$donor_qc) {
    next QC if !$discordance_qc->{sample1_public_name} || !$discordance_qc->{sample2_public_name};
    print $discordance_genotyping_fh join("\t", @{$discordance_qc}{qw(sample1_public_name sample2_public_name sample1_control sample2_control discordance num_of_sites avg_min_depth)}), "\n";
  }
  QC:
  foreach my $discordance_qc (grep {$_->{type} eq 'discordance_fluidigm'} @$donor_qc) {
    next QC if !$discordance_qc->{sample1_public_name} || !$discordance_qc->{sample2_public_name};
    print $discordance_fluidigm_fh join("\t", @{$discordance_qc}{qw(sample1_public_name sample2_public_name sample1_control sample2_control discordance num_of_sites avg_min_depth)}), "\n";
  }
  QC:
  foreach my $pluritest_qc (grep {$_->{type} eq 'pluritest_summary'} @$donor_qc) {
    print $pluritest_fh join("\t", @{$pluritest_qc}{qw(sample pluri_raw pluri_logit_p novelty novelty_logit_p rmsd)}), "\n";
  }
  QC:
  foreach my $cnv_qc (grep {$_->{type} eq 'copy_number_summary'} @$donor_qc) {
    print $cnv_fh join("\t", @{$cnv_qc}{qw(sample ND LD SD)}), "\n";
  }
  QC:
  foreach my $cnv_qc (grep {$_->{type} eq 'aberrant_regions'} @$donor_qc) {
    print $cnv_aberrant_region_fh join("\t", @{$cnv_qc}{qw(sample cn chr start end length quality)}), "\n";
    if (my $remote_path = $cnv_qc->{graph}) {
      my ($remote_name, $remote_dir) = fileparse($remote_path);
      my ($suffix) = $remote_name =~ /\.(\w+)$/;
      my $local_dir = join('/', $plot_directory, 'cnv_aberrant_regions', $donor_name);
      $local_dir =~ s{//}{/}g;
      my $local_path = $local_dir . '/' . join('.', $cnv_qc->{sample}, 'cnv_aberrant_regions', 'chr'.$cnv_qc->{chr} , $cnv_qc->{start} . '-' . $cnv_qc->{end},  $suffix);
      if (! -f $local_path) {
        make_path($local_dir);
        copy($remote_path, $local_path) or die "failed to move $remote_path to $local_path";
      }
    }
  }
  QC:
  foreach my $cnv_qc (grep {$_->{type} eq 'aberrant_polysomy'} @$donor_qc) {
    print $cnv_polysomy_fh join("\t", @{$cnv_qc}{qw(sample chr)}), "\n";
    if (my $remote_path = $cnv_qc->{graph}) {
      my ($remote_name, $remote_dir) = fileparse($remote_path);
      my ($suffix) = $remote_name =~ /\.(\w+)$/;
      my $local_dir = join('/', $plot_directory, 'aberrant_polysomy', $donor_name);
      $local_dir =~ s{//}{/}g;
      my $local_path = $local_dir . '/' . join('.', $cnv_qc->{sample}, 'aberrant_polysomy', 'chr'.$cnv_qc->{chr} , $suffix);
      if (! -f $local_path) {
        make_path($local_dir);
        copy($remote_path, $local_path) or die "failed to move $remote_path to $local_path";
      }
    }
  }
  QC:
  foreach my $loh_qc (grep {$_->{type} eq 'loh_calls'} @$donor_qc) {
    print $loh_fh join("\t", @{$loh_qc}{qw(control_sample sample chr start end count)}), "\n";
  }

  foreach my $pluri_plot (grep {$_->{type} eq 'pluritest_plot'} @$donor_qc) {
    my $remote_path = $pluri_plot->{path};
    my ($remote_name, $remote_dir) = fileparse($remote_path);
    my ($suffix) = $remote_name =~ /\.(\w+)$/;
    my $local_dir = join('/', $plot_directory, 'pluritest', $donor_name);
    $local_dir =~ s{//}{/}g;
    my $local_path = $local_dir . '/' . join('.', $donor_name, 'pluritest', $pluri_plot->{order}, $suffix);
    if (! -f $local_path) {
      make_path($local_dir);
      copy($remote_path, $local_path) or die "failed to move $remote_path to $local_path";
    }
  }
  foreach my $copy_number_plot (grep {$_->{type} eq 'copy_number_plot'} @$donor_qc) {
    my $remote_path = $copy_number_plot->{plot};
    my ($remote_name, $remote_dir) = fileparse($remote_path);
    my ($suffix) = $remote_name =~ /\.(\w+)$/;
    my $local_dir = join('/', $plot_directory, 'copy_number', $donor_name);
    $local_dir =~ s{//}{/}g;
    my $local_path = $local_dir . '/' . join('.', $donor_name, 'copy_number', $suffix);
    if (! -f $local_path) {
      make_path($local_dir);
      copy($remote_path, $local_path) or die "failed to move $remote_path to $local_path";
    }
  }
}
  


close $gender_fh;
close $discordance_genotyping_fh;
close $discordance_fluidigm_fh;
close $pluritest_fh;
close $cnv_fh;
close $cnv_aberrant_region_fh;
close $cnv_polysomy_fh;
close $loh_fh;
