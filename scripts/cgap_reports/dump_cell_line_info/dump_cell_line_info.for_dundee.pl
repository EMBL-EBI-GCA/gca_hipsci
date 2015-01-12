#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors improve_tissues improve_ips_lines);
use Text::Delimited;
use ReseqTrack::DBSQL::DBAdaptor;
use Getopt::Long;
use BioSD;
use List::Util qw();

my $demographic_filename;
my $growing_conditions_filename;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
&GetOptions(
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
	    'dbhost=s'      => \$dbhost,
	    'dbname=s'      => \$dbname,
	    'dbuser=s'      => \$dbuser,
	    'dbpass=s'      => \$dbpass,
	    'dbport=s'      => \$dbport,
);

die "did not get a demographic file on the command line" if !$demographic_filename;

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor;

my ($donors, $tissues, $ips_lines) = @{read_cgap_report(days_old=>7)}{qw(donors tissues ips_lines)};
$donors = improve_donors(donors=>$donors, demographic_file=>$demographic_filename);
$tissues = improve_tissues(tissues=>$tissues);
$ips_lines = improve_ips_lines(ips_lines=>$ips_lines, growing_conditions_file =>$growing_conditions_filename);


my @output_fields = qw( name derived_from biosample_id tissue_biosample_id
    donor_biosample_id derived_from_cell_type reprogramming gender age disease
    ethnicity growing_conditions sent_to_dundee RNAseq gexarray_id peptracker_id);
print join("\t", @output_fields), "\n";

my @output_lines;
DONOR:
foreach my $donor (@$donors) {
  TISSUE:
  foreach my $tissue (@{$donor->tissues}) {

    IPS_LINE:
    foreach my $ips_line (@{$tissue->ips_lines}) {
      next IPS_LINE if !$ips_line->biosample_id;
      next IPS_LINE if !$ips_line->qc1;
      my $reprogramming_tech = $ips_line->reprogramming_tech;
      $reprogramming_tech = $reprogramming_tech ? lc($reprogramming_tech) : undef;

      my $ips_name = $ips_line->name;
      my $rnaseq_files = $fa->fetch_by_filename("$ips_name.%.gexarray.%idat");
      my @gexarray_ids;
      foreach my $rnaseq_file (grep {$_->host_id ==1} @$rnaseq_files) {
        my @filename_parts = split('\.', $rnaseq_file->filename);
        die "unexpected name @filename_parts" if $filename_parts[0] ne $ips_name;
        die "unexpected name @filename_parts" if $filename_parts[3] ne 'gexarray';
        push(@gexarray_ids, $filename_parts[2]);
      }

      my $proteomics_files = $fa->fetch_by_filename("%/$ips_name/%.raw");
      my %proteomics_ids;
      foreach my $proteomics_file (grep {$_->host_id ==1} @$proteomics_files) {
        my ($proteomics_id) = $proteomics_file->filename =~ /([A-Z]+\d+)/;
        $proteomics_ids{$proteomics_id} = 1;
      }

      my $sent_to_dundee = $ips_line->release_to_dundee // '';
      $sent_to_dundee =~ s/ .*//;

      my %output = (name => $ips_line->name, derived_from => $tissue->name,
          biosample_id => $ips_line->biosample_id,
          tissue_biosample_id => $tissue->biosample_id,
          donor_biosample_id => $donor->biosample_id,
          derived_from_cell_type => $tissue->type,
          reprogramming => $reprogramming_tech,
          gender => $donor->gender,
          age => $donor->age,
          disease => $donor->disease,
          ethnicity => $donor->ethnicity,
          growing_conditions => $ips_line->growing_conditions,
          sent_to_dundee => $sent_to_dundee,
          RNAseq => (scalar @gexarray_ids ? 1 : 0),
          gexarray_id => join(',', @gexarray_ids),
          peptracker_id => join(',', sort {$a cmp $b} keys %proteomics_ids),
      );
      push(@output_lines, [$ips_line->biosample_id, join("\t", map {$_ // ''} @output{@output_fields})]);

    }
  }
}
print map {$_->[1], "\n"} sort {$a->[0] cmp $b->[0]} @output_lines;
