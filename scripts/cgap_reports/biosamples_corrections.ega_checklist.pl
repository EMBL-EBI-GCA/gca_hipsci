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
    print join("\t", $biosample->id, 'characteristic[donor_id]', $donor->biosample_id, 'NULL', 'NULL',  'NULL', 'NULL', 'NULL'), "\n";

    my @phenotype_strings;

    if (my $disease = $donor->disease) {
      push(@phenotype_strings, $disease eq 'normal' ? 'PATO:0000461'
                  : $disease =~ /bardet-/ ? 'Orphanet:110'
                  : $disease eq 'neonatal diabetes' ? 'Orphanet:552'
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