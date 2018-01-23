#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

#my $tissues = read_cgap_report(file=>'/nfs/research1/hipsci/drop/hip-drop/incoming/cgap_dnap_reports/20140715.hipsci_progress.csv')->{tissues};
my $tissues = read_cgap_report()->{tissues};
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

TISSUE:
foreach my $tissue (@$tissues) {
  my $tissue_id = $tissue->biosample_id;
  next TISSUE if !$tissue_id;
  my $biosd_tissue = BioSD::fetch_sample($tissue_id);
  next TISSUE if !$biosd_tissue;
  #die "error with $tissue_id" if !$biosd_tissue;

  my @biosd_names;
  push(@biosd_names, $biosd_tissue->property('Sample Name')->values->[0]);
  push(@biosd_names, @{$biosd_tissue->property('synonym')->values});
  my $cgap_name = $tissue->name;
  if (!grep {$_ eq $cgap_name} @biosd_names) {
    print join("\t", $tissue_id, 'comment[synonym]', $cgap_name, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
  }

  my $biosd_material = $biosd_tissue->property('Material');
  if (!$biosd_material) {
    print join("\t", $tissue_id, 'Material', 'cell line', 'EFO', 'http://www.ebi.ac.uk/efo/EFO_0000322', 'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
  }

  my $biosd_cell_type = $biosd_tissue->property('cell type');
  my $cgap_cell_type = $tissue->type;
  if ($cgap_cell_type && $cgap_cell_type =~ /Skin Tissue/i) {
    if (!$biosd_cell_type || $biosd_cell_type->values->[0] ne 'fibroblast') {
        print join("\t", $tissue_id, 'characteristic[cell type]', 'fibroblast', 'EFO', 'http://purl.obolibrary.org/obo/CL_0000057', 'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
    }
  }
  elsif ($cgap_cell_type && $cgap_cell_type =~ /Whole blood/i) {
    if (!$biosd_cell_type || $biosd_cell_type->values->[0] ne 'pbmc') {
        print join("\t", $tissue_id, 'characteristic[cell type]', 'pbmc', 'EFO', 'http://purl.obolibrary.org/obo/CL_0000842', 'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
    }
  }
  elsif($cgap_cell_type) {
    die "unrecognised cell type $tissue_id $cgap_cell_type";
  }


  my $biosd_derived_from = $biosd_tissue->derived_from()->[0];
  my $donor = $tissue->donor;
  if ($donor && $donor->biosample_id) {
    if (!$biosd_derived_from || $biosd_derived_from->id ne $donor->biosample_id) {
        print join("\t", $tissue_id, 'Derived From', $donor->biosample_id, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
    }
  }

}



