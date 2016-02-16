#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use BioSD;
use Text::Delimited;

my $file = $ARGV[0] || die "did not get a file on the command line";

my $donors = read_cgap_report()->{donors};
improve_donors(donors=>$donors, demographic_file=>$file);
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

DONOR:
foreach my $donor (@$donors) {

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

  foreach my $biosample (grep {$_->is_valid} map {BioSD::Sample->new($_)} @biosd_ids) {
    if (my $disease = $donor->disease) {
      if ($disease = 'neonatal diabetes'){$disease = 'monogenic diabetes'}
      my $efo_term = $disease eq 'normal' ? 'http://www.ebi.ac.uk/efo/EFO_0000761'
                  : $disease =~ /bardet-/ ? 'http://www.orpha.net/ORDO/Orphanet_110'
                  : $disease eq 'monogenic diabetes' ? 'http://www.orpha.net/ORDO/Orphanet_552'
                  : $disease eq 'ataxia' ? 'http://www.orpha.net/ORDO/Orphanet_183518'
                  : $disease eq 'usher syndrome' ? 'http://www.orpha.net/ORDO/Orphanet_886'
                  : die "did not recognise disease $disease ".$biosample->id;
      my $biosd_disease = $biosample->property('disease state');
      #if (!$biosd_disease || ! grep { /$disease/i } @{$biosd_disease->values}) {
      if (!$biosd_disease) {
        print join("\t", $biosample->id, 'characteristic[disease state]', $disease, 'EFO', $efo_term,  'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
      }
      #elsif (! grep { /$disease/i } @{$biosd_disease->values}) {
      #  die "disagreement for disease $disease ".$biosample->id;
      #}
    }
    if (my $gender = $donor->gender) {
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
    if (my $age = $donor->age) {
      my $biosd_age = $biosample->property('age');
      #if (!$biosd_age || ! grep { $_ eq $age_band } @{$biosd_age->values}) {
      if (!$biosd_age) {
        print join("\t", $biosample->id, 'characteristic[age]', $age, 'EFO', 'http://www.ebi.ac.uk/efo/EFO_0001725',  'http://www.ebi.ac.uk/efo', 'NULL', 'year'), "\n";
      }
      elsif (! grep { $_ eq $age} @{$biosd_age->values}) {
        die "disagreement for age $age".$biosample->id;
      }
    }
    if (my $ethnicity = $donor->ethnicity) {
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
