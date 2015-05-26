#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors improve_tissues improve_ips_lines);
use Text::Delimited;
use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellomics';
my $dbuser = 'g1krw';
my $dbpass;
my $demographic_filename;
my $growing_conditions_filename;
&GetOptions(
  'dbhost=s' => \$dbhost,
  'dbport=s' => \$dbport,
  'dbname=s' => \$dbname,
  'dbuser=s' => \$dbuser,
  'dbpass=s' => \$dbpass,
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
);

die "did not get a demographic file on the command line" if !$demographic_filename;

my $dbh = DBI->connect(
  "dbi:mysql:dbname=$dbname;host=$dbhost;port=$dbport",
  $dbuser, $dbpass,
) or die $DBI::errstr;


my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>7)}{qw(donors tissues ips_lines)};
$donors = improve_donors(donors=>$donors, demographic_file=>$demographic_filename);
$tissues = improve_tissues(tissues=>$tissues);
$ips_lines = improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file =>$growing_conditions_filename);


my $sql1 = <<"SQL";
  INSERT INTO cell_line (
    name,
    short_name,
    donor,
    biosample_id,
    donor_biosample_id,
    cell_type,
    derived_from_tissue_type,
    reprogramming,
    gender,
    age,
    disease,
    ethnicity
  )
  VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
SQL

my $sth1 = $dbh->prepare($sql1);

DONOR:
foreach my $donor (@$donors) {
  my $donor_name = '';
  if (my $donor_biosample_id = $donor->biosample_id) {
    my $donor_biosample = BioSD::fetch_sample($donor_biosample_id);
    $donor_name = $donor_biosample->property('Sample Name')->values->[0];
  }
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {
    my $tissue_has_data = 0;

    my $tissue_type = $tissue->type;
    $tissue_type = $tissue_type ? lc($tissue_type) : undef;


    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      next IPS_LINE if !$ips_line->biosample_id;
      next IPS_LINE if $ips_line->name !~ /HPSI/;
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;

      my ($ips_short_name) = $ips_line->name =~ /-([a-z]+(?:_\d+)?)$/;
      $sth1->bind_param(1, $ips_line->name);
      $sth1->bind_param(2, $ips_short_name);
      $sth1->bind_param(3, $donor_name);
      $sth1->bind_param(4, $ips_line->biosample_id);
      $sth1->bind_param(5, $donor->biosample_id);
      $sth1->bind_param(6, 'ips');
      $sth1->bind_param(7, $tissue_type);
      $sth1->bind_param(8, $reprogramming_tech);
      $sth1->bind_param(9, $donor->gender);
      $sth1->bind_param(10, $donor->age);
      $sth1->bind_param(11, $donor->disease);
      $sth1->bind_param(12, $donor->ethnicity);

      $sth1->execute;
      $tissue_has_data = 1;

    }
    next TISSUE if !$tissue_has_data;

    my ($tissue_short_name) = $tissue->name =~ /-([a-z]+(?:_\d+)?)$/;
    $sth1->bind_param(1, $tissue->name);
    $sth1->bind_param(2, $tissue_short_name);
    $sth1->bind_param(3, $donor_name);
    $sth1->bind_param(4, $tissue->biosample_id);
    $sth1->bind_param(5, $donor->biosample_id);
    $sth1->bind_param(6, $tissue_type),
    $sth1->bind_param(7, undef);
    $sth1->bind_param(8, undef);
    $sth1->bind_param(9, $donor->gender);
    $sth1->bind_param(10, $donor->age);
    $sth1->bind_param(11, $donor->disease);
    $sth1->bind_param(12, $donor->ethnicity);

    $sth1->execute;
  }
}
