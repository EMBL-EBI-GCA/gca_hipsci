#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use JSON;
use File::Basename qw(fileparse);
use Getopt::Long;
use BioSD;

my $demographic_filename;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $json_file;
my $experiment_design_file;

GetOptions(
    'demographic_file=s' => \$demographic_filename,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'experiment_design_file=s' => \$experiment_design_file,
    'json_file=s'   => \$json_file,
);


my %pep_ids;
open my $fh, '<', $experiment_design_file or die $!;
<$fh>;
while (my $line = <$fh>) {
  chomp $line;
  my ($pep_id, $fraction) = split("\t", $line);
  $pep_id =~ s/-\d*$//;
  $pep_ids{$pep_id} = 1;
}
close $fh;

my $dundee_json = parse_json($json_file);

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

print join("\t",qw(peptracker_id cell_line biosample_id cell_type derived_from_cell_line derived_from_cell_type ipsc_growing_conditions method_of_derivation sex disease_state)), "\n";
PEP_ID:
foreach my $pep_id (sort {$a cmp $b} keys %pep_ids) {
  my ($sample_set) = grep {$_->{sample_groups}->[0]->{samples}->[0]->{sample_identifier} =~ $pep_id} @{$dundee_json->{sample_sets}};

  if ($pep_id eq 'PT4835') {
    print join("\t",
      $pep_id,
      'HPSI_composite_1503',
      '',
      sprintf('reference mixture of %s iPS cell lines', scalar @{$sample_set->{sample_groups}->[0]->{details}->{ips_cells}}),
      '', '', '', '', '', '',
    ), "\n";
    next PEP_ID;
  }

  my $cell_line = $sample_set->{sample_groups}->[0]->{details}->{ips_cells}->[0]->{name} || $sample_set->{sample_groups}->[0]->{details}->{descriptive_name};
  die "did not get cell line name for $pep_id" if !$cell_line;
  $cell_line =~ s/\s.*$//;

  $cell_line = 'zumy' if $cell_line =~ /zumy/;
  $cell_line = 'qifc' if $cell_line =~ /qifc/;

  my $cgap_ips_line = List::Util::first {$_->name =~ /$cell_line$/} @$cgap_ips_lines;
  my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                  : List::Util::first {$_->name =~ /$cell_line$/} @$cgap_tissues;
  die 'did not recognise sample '.$cell_line if !$cgap_tissue;

  if ($cell_line =~ /qifc/) {
    print join("\t",
      $pep_id,
      $cgap_tissue->name,
      'SAMEA3402864',
      'embryonic stem cell',
      '', '', '', '', 'female', 'normal',
    ), "\n";
    next PEP_ID;
  }
  if ($cell_line =~ /zumy/) {
    print join("\t",
      $pep_id,
      $cgap_tissue->name,
      'SAMEA3110364',
      'embryonic stem cell',
      '', '', '', '', 'male', 'normal',
    ), "\n";
    next PEP_ID;
  }

  my $source_material = CORE::fc($cgap_tissue->tissue_type) eq CORE::fc('skin tissue') ? 'fibroblast'
                : CORE::fc($cgap_tissue->tissue_type) eq CORE::fc('whole blood') ? 'PBMC'
                : die 'did not recognise source material '.$cgap_tissue->tissue_type;

  my $cell_type = $cgap_ips_line ? 'induced pluripotent stem cell' : $source_material;

  my $growing_conditions;
  my $method_of_derivation;
  if ($cgap_ips_line) {
    my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$cgap_ips_line->release_to_dundee);
    $growing_conditions = $cgap_release && $cgap_release->is_feeder_free ? 'feeder-free'
                      : $cgap_release && !$cgap_release->is_feeder_free ? 'feeder-dependent'
                      : $cell_line =~ /_\d\d$/ ? 'feeder-free'
                      : $cgap_ips_line->passage_ips && $cgap_ips_line->passage_ips lt 20140000 ? 'feeder-dependent'
                      : $cgap_ips_line->qc1 && $cgap_ips_line->qc1 lt 20140000 ? 'feeder-dependent'
                      : die "could not get growing conditions for $cell_line";

    my $biosample = BioSD::fetch_sample($cgap_ips_line->biosample_id);
    if (my $method_property = $biosample->property('method of derivation')) {
      $method_of_derivation = $method_property->values->[0];
    }
  }

  print join("\t",
    $pep_id,
    ($cgap_ips_line ? $cgap_ips_line->name : $cgap_tissue->name),
    ($cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id),
    $cell_type,
    ($cgap_ips_line ? $cgap_tissue->name : ''),
    ($cgap_ips_line ? $source_material : ''),
    $growing_conditions || '',
    $method_of_derivation || '',
    $cgap_tissue->donor->gender || '',
    $cgap_tissue->donor->disease || '',
#    $cgap_tissue->donor->age || '',
#    $cgap_tissue->donor->ethnicity || '',
#    $sample_set->{sample_groups}->[0]->{details}->{chromatography_columns}->[0]->{column_type}
  ), "\n";

}

sub parse_json {
  my ($json_file) = @_;
  open my $IN, '<', $json_file or die "could not open $json_file $!";
  local $/ = undef;
  my $json = <$IN>;
  close $IN;
  my $decoded_json = JSON->new->utf8->decode($json);
  return $decoded_json;
}
