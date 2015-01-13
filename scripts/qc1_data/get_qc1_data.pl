#!/usr/bin/env perl

use strict;
use warnings;

use Net::OpenSSH;
use Net::SFTP::Foreign;
use LWP::UserAgent;
use JSON;
use List::Util qw();
use Getopt::Long;
use File::Basename qw(fileparse);
use POSIX qw(strftime);
use ReseqTrack::Tools::FileSystemUtils qw(check_directory_exists);

my $ssh_password;
my $ssh_user = 'is6';
my $ssh_host = 'ssh.sanger.ac.uk';
my $output = 'hipsci.qc1';
my $filesystem_password;
my $plot_directory;
my $ssh_config_file = '/homes/streeter/.ssh/config';
my $ssh_known_hosts_file = '/homes/streeter/.ssh/known_hosts';
my $donor_id;
GetOptions('ssh_user=s' => \$ssh_user,
          'ssh_host=s' => \$ssh_host,
          'ssh_password=s' => \$ssh_password,
          'ssh_config_file=s' => \$ssh_config_file,
          'ssh_known_hosts_file=s' => \$ssh_known_hosts_file,
          'output=s' => \$output,
          'filesystem_password=s' => \$filesystem_password,
          'plot_directory=s' => \$plot_directory,
          'donor_id=s' => \$donor_id,
          );

die "no donor id" if !$donor_id;

my $ssh = Net::OpenSSH->new($ssh_host, user => $ssh_user, password=>$ssh_password,
    master_opts => [-F => $ssh_config_file, -o => "UserKnownHostsFile $ssh_known_hosts_file"],
);
my $sftp = Net::SFTP::Foreign->new(host => 'localhost', user => $ssh_user, port => 9091, password => $filesystem_password, autodie => 1);

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
$ua->default_header('Content-Type' => 'application/json');
my $json = JSON->new->allow_nonref;

open my $gender_fh, '>', $output.'.gender.tsv' or die "could not open $output $!";
open my $discordance_genotyping_fh, '>', $output.'.discordance_genotyping.tsv' or die "could not open $output $!";
open my $discordance_fluidigm_fh, '>', $output.'.discordance_fluidigm.tsv' or die "could not open $output $!";
open my $pluritest_fh, '>', $output.'.pluritest.tsv' or die "could not open $output $!";
open my $cnv_fh, '>', $output.'.cnv_summary.tsv' or die "could not open $output $!";
open my $cnv_aberrant_region_fh, '>', $output.'.cnv_aberrant_region.tsv' or die "could not open $output $!";
open my $cnv_polysomy_fh, '>', $output.'.cnv_polysomy.tsv' or die "could not open $output $!";
open my $loh_fh, '>', $output.'.loh.tsv' or die "could not open $output $!";

print $gender_fh join("\t", qw(sample_public_name sample_name expected_gender actual_gender)), "\n";
print $discordance_genotyping_fh join("\t", qw(sample1 sample2 sample1_is_control sample2_is_control discordance num_of_sites avg_min_depth)), "\n";
print $discordance_fluidigm_fh join("\t", qw(sample1 sample2 sample1_is_control sample2_is_control discordance num_of_sites avg_min_depth)), "\n";
print $pluritest_fh join("\t", qw(sample pluri_raw pluri_logit_p novelty novelty_logit_p rmsd)), "\n";
print $cnv_fh join("\t", qw(sample num_different_regions length_different_regions_Mbp length_shared_differences_Mbp)), "\n";
print $cnv_aberrant_region_fh join("\t", qw(sample copy_number chromosome start end length quality)), "\n";
print $cnv_polysomy_fh join("\t", qw(sample chromosome)), "\n";
print $loh_fh join("\t", qw(control_sample sample chromosome start end count)), "\n";

$donor_id += 0; # forces it to be treated as a number in the json encoding
my $response;
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
foreach my $pluritest_qc (grep {$_->{type} eq 'pluritest_summary'} @$donor_qc) {
  print $pluritest_fh join("\t", @{$pluritest_qc}{qw(sample pluri_raw pluri_logit_p novelty novelty_logit_p rmsd)}), "\n";
}
foreach my $cnv_qc (grep {$_->{type} eq 'copy_number_summary'} @$donor_qc) {
  print $cnv_fh join("\t", @{$cnv_qc}{qw(sample ND LD SD)}), "\n";
}
foreach my $cnv_qc (grep {$_->{type} eq 'aberrant_regions'} @$donor_qc) {
  print $cnv_aberrant_region_fh join("\t", @{$cnv_qc}{qw(sample cn chr start end length quality)}), "\n";
  if (my $remote_path = $cnv_qc->{graph}) {
    my ($remote_name, $remote_dir) = fileparse($remote_path);
    my $remote_details = List::Util::first {$_->{filename} eq $remote_name} @{$sftp->ls($remote_dir)};
    my $epoch = $remote_details->{a}->mtime;
    my $date = strftime('%Y%m%d', localtime($epoch));
    my ($suffix) = $remote_name =~ /\.(\w+)$/;
    my $local_dir = join('/', $plot_directory, 'cnv_aberrant_regions', $donor_name);
    $local_dir =~ s{//}{/}g;
    my $local_path = $local_dir . '/' . join('.', $cnv_qc->{sample}, 'cnv_aberrant_regions', $date, 'chr'.$cnv_qc->{chr} , $cnv_qc->{start} . '-' . $cnv_qc->{end},  $suffix);
    if (! -f $local_path) {
      check_directory_exists($local_dir);
      $sftp->get($remote_path, $local_path);
    }
  }
}
foreach my $cnv_qc (grep {$_->{type} eq 'aberrant_polysomy'} @$donor_qc) {
  print $cnv_polysomy_fh join("\t", @{$cnv_qc}{qw(sample chr)}), "\n";
  if (my $remote_path = $cnv_qc->{graph}) {
    my ($remote_name, $remote_dir) = fileparse($remote_path);
    my $remote_details = List::Util::first {$_->{filename} eq $remote_name} @{$sftp->ls($remote_dir)};
    my $epoch = $remote_details->{a}->mtime;
    my $date = strftime('%Y%m%d', localtime($epoch));
    my ($suffix) = $remote_name =~ /\.(\w+)$/;
    my $local_dir = join('/', $plot_directory, 'aberrant_polysomy', $donor_name);
    $local_dir =~ s{//}{/}g;
    my $local_path = $local_dir . '/' . join('.', $cnv_qc->{sample}, 'aberrant_polysomy', $date, 'chr'.$cnv_qc->{chr} , $suffix);
    if (! -f $local_path) {
      check_directory_exists($local_dir);
      $sftp->get($remote_path, $local_path);
    }
  }
}
foreach my $loh_qc (grep {$_->{type} eq 'loh_calls'} @$donor_qc) {
  print $loh_fh join("\t", @{$loh_qc}{qw(control_sample sample chr start end count)}), "\n";
}

foreach my $pluri_plot (grep {$_->{type} eq 'pluritest_plot'} @$donor_qc) {
  my $remote_path = $pluri_plot->{path};
  my ($remote_name, $remote_dir) = fileparse($remote_path);
  my $remote_details = List::Util::first {$_->{filename} eq $remote_name} @{$sftp->ls($remote_dir)};
  my $epoch = $remote_details->{a}->mtime;
  my $date = strftime('%Y%m%d', localtime($epoch));
  my ($suffix) = $remote_name =~ /\.(\w+)$/;
  my $local_dir = join('/', $plot_directory, 'pluritest', $donor_name);
  $local_dir =~ s{//}{/}g;
  my $local_path = $local_dir . '/' . join('.', $donor_name, 'pluritest', $pluri_plot->{order}, $date, $suffix);
  if (! -f $local_path) {
    check_directory_exists($local_dir);
    $sftp->get($remote_path, $local_path);
  }
}
foreach my $copy_number_plot (grep {$_->{type} eq 'copy_number_plot'} @$donor_qc) {
  my $remote_path = $copy_number_plot->{plot};
  my ($remote_name, $remote_dir) = fileparse($remote_path);
  my $remote_details = List::Util::first {$_->{filename} eq $remote_name} @{$sftp->ls($remote_dir)};
  my $epoch = $remote_details->{a}->mtime;
  my $date = strftime('%Y%m%d', localtime($epoch));
  my ($suffix) = $remote_name =~ /\.(\w+)$/;
  my $local_dir = join('/', $plot_directory, 'copy_number', $donor_name);
  $local_dir =~ s{//}{/}g;
  my $local_path = $local_dir . '/' . join('.', $donor_name, 'copy_number', $date, $suffix);
  if (! -f $local_path) {
    check_directory_exists($local_dir);
    $sftp->get($remote_path, $local_path);
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
