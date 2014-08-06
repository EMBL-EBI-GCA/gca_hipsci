#!/usr/bin/env perl

use strict;
use warnings;

use HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Text::Delimited;
use DBI;
use Getopt::Long;

my $dbhost='mysql-g1kdcc-public';
my $dbport = 4197;
my $dbname = 'hipsci_cellomics';
my $dbuser = 'g1krw';
my $dbpass;
my $file;
&GetOptions(
  'dbhost=s' => \$dbhost,
  'dbport=s' => \$dbport,
  'dbname=s' => \$dbname,
  'dbuser=s' => \$dbuser,
  'dbpass=s' => \$dbpass,
  'file=s' => \$file,
);

die "did not get a file on the command line" if !$file;

my $dbh = DBI->connect(
  "dbi:mysql:dbname=$dbname;host=$dbhost;port=$dbport",
  $dbuser, $dbpass,
) or die $DBI::errstr;

my %demographics;
my $demographic_file = new Text::Delimited;
$demographic_file->delimiter(";");
$demographic_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $demographic_file->read) {
  my $gender = $line_data->{'Gender'} // '';
  $gender =~ s/[^\w]//g;
  $demographics{$line_data->{'DonorID'}} = $line_data;
}
$demographic_file->close;

my $donors = read_cgap_report()->{donors};

my $sql1 = <<"SQL";
  INSERT INTO cell_line (
    name,
    short_name,
    biosample_id,
    cell_type,
    derived_from_tissue_type,
    reprogramming,
    gender,
    age,
    disease,
    ethnicity
  )
  VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
SQL

my $sth1 = $dbh->prepare($sql1);

DONOR:
foreach my $donor (@$donors) {
  my $donor_demographics = $demographics{$donor->supplier_name} // {};
  my $gender = $donor_demographics->{'Gender'};
  my $disease = $donor_demographics->{'Disease phenotype'};
  my $age = $donor_demographics->{'Age-band'};
  my $ethnicity = $donor_demographics->{'Ethnicity'};
  if ($gender) {
    $gender = lc($gender);
    $gender =~ s/[^\w]//g;
  }
  $disease = $disease ? lc($disease) : undef;
  $age = $age ? lc($age) : undef;
  $ethnicity = $ethnicity ? lc($ethnicity) : undef;
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {
    my $tissue_type = $tissue->type;
    $tissue_type = $tissue_type ? lc($tissue_type) : undef;
    my ($tissue_short_name) = $tissue->name =~ /-([a-z]+(?:_\d+)?)$/;
    $sth1->bind_param(1, $tissue->name);
    $sth1->bind_param(2, $tissue_short_name);
    $sth1->bind_param(3, $tissue->biosample_id);
    $sth1->bind_param(4, $tissue_type),
    $sth1->bind_param(5, undef);
    $sth1->bind_param(6, undef);
    $sth1->bind_param(7, $gender);
    $sth1->bind_param(8, $age);
    $sth1->bind_param(9, $disease);
    $sth1->bind_param(10, $ethnicity);

    $sth1->execute;


    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;

      my ($ips_short_name) = $ips_line->name =~ /-([a-z]+(?:_\d+)?)$/;
      $sth1->bind_param(1, $ips_line->name);
      $sth1->bind_param(2, $ips_short_name);
      $sth1->bind_param(3, $ips_line->biosample_id);
      $sth1->bind_param(4, 'ips');
      $sth1->bind_param(5, $tissue_type),
      $sth1->bind_param(6, $reprogramming_tech),
      $sth1->bind_param(7, $gender);
      $sth1->bind_param(8, $age);
      $sth1->bind_param(9, $disease);
      $sth1->bind_param(10, $ethnicity);

      $sth1->execute;

    }
  }
}
