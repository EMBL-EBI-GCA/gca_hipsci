#!/usr/bin/env perl

use strict;
use warnings;

use HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;
use Text::Delimited;

my $file = $ARGV[0] || die "did not get a file on the command line";

my $donors = read_cgap_report()->{donors};
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

my $demographic_file = new Text::Delimited;
$demographic_file->delimiter(";");
$demographic_file->open($file) or die "could not open $file $!";
LINE:
while (my $line_data = $demographic_file->read) {
  my $donor_name = $line_data->{DonorID};
  my ($donor) = grep {$_->supplier_name eq $donor_name} @$donors;
  next LINE if !$donor;

  my @biosd_ids;
  if (my $donor_id = $donor->biosample_id) {
    push(@biosd_ids, $donor_id);
  }
  foreach my $tissue (@{$donor->tissues}) {
    if (my $tissue_id = $tissue->biosample_id) {
      push(@biosd_ids, $tissue_id);
    }
    foreach my $ips_line (@{$tissue->ips_lines}) {
      if (my $ips_line_id = $ips_line->biosample_id) {
        push(@biosd_ids, $ips_line_id);
      }
    }
  }

  my $disease = $line_data->{'Disease phenotype'};
  my $gender = $line_data->{'Gender'};
  my $age_band = $line_data->{'Age-band'};
  my $ethnicity = $line_data->{'Ethnicity'};

  foreach my $biosample (grep {$_->is_valid} map {BioSD::Sample->new($_)} @biosd_ids) {
    if ($disease) {
      $disease = lc($disease);
      my ($disease_name, $efo_term) = $disease eq 'normal' ? ('normal', 'http://www.ebi.ac.uk/efo/EFO_0000761')
                  : $disease eq 'bbs' ? ('bardet-biedl syndrome', 'http://www.orpha.net/ORDO/Orphanet_110')
                  : $disease eq 'nd' ? ('neonatal diabetes', 'http://www.orpha.net/ORDO/Orphanet_224')
                  : die "did not recognise disease $disease";
      my $biosd_disease = $biosample->property('disease state');
      #if (!$biosd_disease || ! grep { /$disease/i } @{$biosd_disease->values}) {
      if (!$biosd_disease) {
        print join("\t", $biosample->id, 'characteristic[disease state]', $disease_name, 'EFO', $efo_term,  'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
      }
      elsif (! grep { /$disease_name/i } @{$biosd_disease->values}) {
        die "disagreement for disease $disease ".$biosample->id;
      }
    }
    if ($gender && $gender !~ /unknown/i) {
      $gender = lc($gender);
      $gender =~ s/[^\w]//g;
      my $efo_term = $gender eq 'male' ? 'http://www.ebi.ac.uk/efo/EFO_0001266'
                  : $gender eq 'female' ? 'http://www.ebi.ac.uk/efo/EFO_0001265'
                  : die "did not recognise gender $gender";
      my $biosd_gender = $biosample->property('Sex');
      #if (!$biosd_gender || ! grep { lc($_) eq $gender } @{$biosd_gender->values}) {
      if (!$biosd_gender) {
        print join("\t", $biosample->id, 'Sex', $gender, 'EFO', $efo_term,  'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
      }
      elsif (! grep { lc($_) eq $gender } @{$biosd_gender->values}) {
        die "disagreement for gender $gender ".$biosample->id;
      }
    }
    if ($age_band && $age_band !~ /unknown/i) {
      my $biosd_age = $biosample->property('age');
      #if (!$biosd_age || ! grep { $_ eq $age_band } @{$biosd_age->values}) {
      if (!$biosd_age) {
        print join("\t", $biosample->id, 'characteristic[age]', $age_band, 'EFO', 'http://www.ebi.ac.uk/efo/EFO_0001725',  'http://www.ebi.ac.uk/efo', 'NULL', 'year'), "\n";
      }
      elsif (! grep { $_ eq $age_band } @{$biosd_age->values}) {
        die "disagreement for age $age_band ".$biosample->id;
      }
    }
    if ($ethnicity && $ethnicity !~ /unknown/i) {
      my $biosd_ethnicity = $biosample->property('ethnicity');
      #if (!$biosd_ethnicity || ! grep { lc($_) eq lc($ethnicity) } @{$biosd_ethnicity->values}) {
      if (!$biosd_ethnicity) {
        print join("\t", $biosample->id, 'characteristic[ethnicity]', $ethnicity, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
      }
      elsif (! grep { lc($_) eq lc($ethnicity) } @{$biosd_ethnicity->values}) {
        die "disagreement for ethnicity $ethnicity ".$biosample->id;
      }
    }
  }

}
$demographic_file->close;
