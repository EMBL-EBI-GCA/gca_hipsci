#!/usr/bin/env perl

use strict;
use warnings;

use HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use BioSD;

#my $tissues = read_cgap_report(file=>'/nfs/research2/hipsci/drop/hip-drop/incoming/cgap_dnap_reports/20140715.hipsci_progress.csv')->{ips_lines};
my $ips_lines = read_cgap_report()->{ips_lines};
print join("\t", qw(SAMPLE_ID  ATTR_KEY  ATTR_VALUE  TERM_SOURCE_REF TERM_SOURCE_ID  TERM_SOURCE_URI TERM_SOURCE_VERSION UNIT)), "\n";

IPS_LINE:
foreach my $ips_line (@$ips_lines) {
  my $ips_id = $ips_line->biosample_id;
  next IPS_LINE if !$ips_id;
  my $biosd_ips_line = BioSD::fetch_sample($ips_id);
  next IPS_LINE if !$biosd_ips_line;
  #die "error with $tissue_id" if !$biosd_tissue;

  my @biosd_names;
  push(@biosd_names, $biosd_ips_line->property('Sample Name')->values->[0]);
  push(@biosd_names, @{$biosd_ips_line->property('synonym')->values});
  my $cgap_name = $ips_line->name;
  if (!grep {$_ eq $cgap_name} @biosd_names) {
    print join("\t", $ips_id, 'comment[synonym]', $cgap_name, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
  }

  my $biosd_material = $biosd_ips_line->property('Material');
  if (!$biosd_material) {
    print join("\t", $ips_id, 'Material', 'cell line', 'EFO', 'http://www.ebi.ac.uk/efo/EFO_0000322', 'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
  }

  my $biosd_cell_type = $biosd_ips_line->property('cell type');
  if (!$biosd_cell_type || $biosd_cell_type->values->[0] ne 'induced pluripotent stem cell') {
      print join("\t", $ips_id, 'characteristic[cell type]', 'induced pluripotent stem cell', 'EFO', 'http://www.ebi.ac.uk/efo/EFO_0004905', 'http://www.ebi.ac.uk/efo', 'NULL', 'NULL'), "\n";
  }

  my $biosd_derived_from = $biosd_ips_line->derived_from()->[0];
  my $tissue = $ips_line->tissue;
  if ($tissue && $tissue->biosample_id) {
    if (!$biosd_derived_from || $biosd_derived_from->id ne $tissue->biosample_id) {
        print join("\t", $ips_id, 'Derived From', $tissue->biosample_id, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
    }
  }

  my $biosd_reprogramming_tech = $biosd_ips_line->property('method of derivation');
  my $cgap_reprogramming_tech = $ips_line->reprogramming_tech;
  if ($cgap_reprogramming_tech && $cgap_reprogramming_tech =~ /sendai/i) {
    if (!$biosd_reprogramming_tech || $biosd_reprogramming_tech->values->[0] !~ /Sendai/i) {
        print join("\t", $ips_id, 'comment[method of derivation]', 'sendai', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
    }
  }
  elsif ($cgap_reprogramming_tech && $cgap_reprogramming_tech =~ /retrovirus/i) {
    if (!$biosd_reprogramming_tech || $biosd_reprogramming_tech->values->[0] !~ /Retrovirus/i) {
        print join("\t", $ips_id, 'comment[method of derivation]', 'retrovirus', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
    }
  }
  elsif ($cgap_reprogramming_tech && $cgap_reprogramming_tech =~ /episomal/i) {
    if (!$biosd_reprogramming_tech || $biosd_reprogramming_tech->values->[0] !~ /Episomal/i) {
        print join("\t", $ips_id, 'comment[method of derivation]', 'episomal', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
    }
  }
  elsif($cgap_reprogramming_tech) {
    die "unrecognised reprogramming tech $ips_id $cgap_reprogramming_tech";
  }

  my $biosd_sop_url = $biosd_ips_line->property('sop url');
  if (!$biosd_sop_url) {
    print join("\t", $ips_id, 'comment[sop url]', 'http://www.hipsci.org/hipsci-ips-preparation-standard-operating-procedures', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
  }

  my $biosd_date = $biosd_ips_line->property('date of derivation');
  my $cgap_date = $ips_line->ips_created;
  if (!$biosd_date && $biosd_date) {
    $cgap_date =~ s/\s.*//g;
    print join("\t", $ips_id, 'comment[date of derivation]', $cgap_date, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'), "\n";
  }

}



