#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use BioSD;
use List::Util qw(first);
use Text::Delimited;

my $file = $ARGV[0] || die "did not get a file on the command line";

my $donors = read_cgap_report()->{donors};
improve_donors(donors=>$donors, demographic_file=>$file);
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

DONOR:
foreach my $donor (@$donors) {
  next DONOR if $donor->hmdmc && $donor->hmdmc eq 'H1288';

  my @biosd_ids;
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
    my $donor_property = first{$biosample->property($_)} ('donor id', 'donor_id', 'subject_id', 'subject id');
    my $phenotype_property = $biosample->property('phenotype');
    my $sex_property = first{$biosample->property($_)} ('sex', 'Sex', 'gender');


    if (!$donor_property) {
      print join("\t", $biosample->id, 'characteristic[donor id]', $donor->biosample_id, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
    }
    if (!$sex_property) {
      if (my $gender = $donor->gender) {
        my $efo_term = $gender eq 'male' ? 'http://www.ebi.ac.uk/efo/EFO_0001266'
                    : $gender eq 'female' ? 'http://www.ebi.ac.uk/efo/EFO_0001265'
                    : die "did not recognise gender $gender";
          print join("\t", $biosample->id, 'characteristic[sex]', $gender, 'EFO', $efo_term,  'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
      }
    }
    if (!$phenotype_property) {

      my @phenotype_strings;

      if (my $disease = $donor->disease) {
        push(@phenotype_strings, $disease eq 'normal' ? 'PATO:0000461'
                    : $disease =~ /bardet-/ ? 'Orphanet:110'
                    : $disease eq 'monogenic diabetes' ? 'Orphanet:552'
                    : $disease =~ /ataxia/ ? 'Orphanet:183518'
                    : $disease =~ /usher syndrome/ ? 'Orphanet:886'
                    : $disease eq 'kabuki syndrome' ? 'Orphanet:2322'
                    : $disease eq 'hypertrophic cardiomyopathy' ? 'Orphanet:217569'
                    : $disease eq 'alport syndrome' ? 'Orphanet:63'
                    : $disease eq 'bleeding and platelet disorder' ? 'EFO:0005803'
                    : $disease eq 'primary immune deficiency' ? 'EFO:0000540'
                    : $disease eq 'batten disease' ? 'DOID:0050756'
                    : $disease eq 'retinitis pigmentosa' ? 'Orphanet:791'
                    : $disease eq 'genetic macular dystrophy' ? 'Orphanet:98664'
                    : $disease =~ /spastic paraplegia/ ? 'HP:0001258'
                    : $disease =~ /congenital hyperins/ ? 'OMIT:0023511'
                    : $disease eq 'rare genetic neurological disorder' ? 'Orphanet:71859'
                    : die "did not recognise disease $disease ".$biosample->id);
      }
      if (my $cell_type_property = $biosample->property('cell type')) {
        foreach my $phenotype_string (map {$_->term_source->term_source_id} @{$cell_type_property->qualified_values()}) {
          $phenotype_string =~ s/_/:/;
          push (@phenotype_strings, $phenotype_string);
        }
      }

      if (@phenotype_strings) {
        print join("\t", $biosample->id, 'characteristic[phenotype]', join(';', @phenotype_strings), 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";
      }
    }
  }

}
