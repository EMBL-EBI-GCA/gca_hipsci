#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use Getopt::Long;
use XML::Simple qw(XMLin);

my @era_params = ('ops$laura', undef, 'ERAPRO');
my @study_id;
my $demographic_filename;

GetOptions(
    'era_password=s'    => \$era_params[1],
    'study_id=s'    => \@study_id,
    'demographic_file=s' => \$demographic_filename,
);

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my $sql_study =  'select xmltype.getclobval(study_xml) study_xml from study where study_id=?';
my $sth_study = $era_db->dbc->prepare($sql_study) or die "could not prepare $sql_study";

my $sql_run =  "
  select r.run_id, to_char(r.first_created, 'YYYY-MM-DD') first_created, r.experiment_id, xmltype.getclobval(r.run_xml) run_xml, s.biosample_id, e.instrument_platform, e.instrument_model, e.library_layout, e.library_strategy, e.library_source, e.library_selection, e.paired_nominal_length, xmltype.getclobval(e.experiment_xml) experiment_xml
  from sample s, run_sample rs, run r, experiment e
  where r.experiment_id=e.experiment_id and r.run_id=rs.run_id
  and s.sample_id=rs.sample_id
  and r.status_id=4
  and e.study_id=?
  ";
my $sth_run = $era_db->dbc->prepare($sql_run) or die "could not prepare $sql_run";

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

foreach my $study_id (@study_id) {
  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});
  my $assay = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /exome\W*seq/i ? 'exomeseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /whole\W*genome\W*sequencing/i ? 'wgs'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /exome\W*seq/i ? 'exomeseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /whole\W*genome\W*sequencing/i ? 'wgs'
            : die "did not recognise assay for $study_id";
  my $disease = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /healthy/i ? 'healthy volunteers'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrome'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /diabetes/i ? 'neonatal diabetes mellitus'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /reference_set/i ? 'healthy volunteers'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /healthy/i ? 'healthy volunteers'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrome'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /diabetes/i ? 'neonatal diabetes mellitus'
            : die "did not recognise disease for $study_id";
  my $filename_disease = lc($disease);
  $filename_disease =~ s{[ -]}{_}g;

  my $output = join('.', 'ENA', $study_id, $assay, $filename_disease, 'run_files', 'tsv');
  open my $fh, '>', $output or die "could not open $output $!";
  print $fh '##ENA study title: ', $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}, "\n";
  print $fh "##ENA study ID: $study_id\n";
  print $fh '##Assay: ', ($assay eq 'exomeseq' ? 'Exome-seq' : $assay eq 'rnaseq' ? 'RNA-seq' : $assay eq 'wgs' ? 'Whole genome sequencing' : die "did not recognise assay $assay"), "\n";
  print $fh "##Disease cohort: $disease\n";
  print $fh '#', join("\t", qw(
    file_url md5 cell_line biosample_id run_id experiment_id study_id archive_submission_date cell_type source_material sex growing_conditions 
      instrument_platform instrument_model library_layout library_strategy library_source library_selection insert_size library_construction_protocol
  )), "\n";

  $sth_run->bind_param(1, $study_id);
  $sth_run->execute or die "could not execute";

  ROW:
  while (my $row = $sth_run->fetchrow_hashref) {
    my $xml_hash = XMLin($row->{RUN_XML});
    my $experiment_xml_hash = XMLin($row->{EXPERIMENT_XML});
    my $file = $xml_hash->{RUN}{DATA_BLOCK}{FILES}{FILE};
    my $cgap_ips_line = List::Util::first {$_->biosample_id && $_->biosample_id eq $row->{BIOSAMPLE_ID}} @$cgap_ips_lines;
    my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                    : List::Util::first {$_->biosample_id eq $row->{BIOSAMPLE_ID}} @$cgap_tissues;
    die 'did not recognise sample '.$row->{BIOSAMPLE_ID} if !$cgap_tissue;

    my $sample_name = $cgap_ips_line ? $cgap_ips_line->name : $cgap_tissue->name;
    my $source_material = $cgap_tissue->tissue_type || '';
    my $cell_type = $cgap_ips_line ? 'iPSC'
                  : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                  : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                  : die "did not recognise source material $source_material";

    my $run_time = DateTime::Format::ISO8601->parse_datetime($row->{FIRST_CREATED})->subtract(days => 90);
    my $growing_conditions;
    if ($cgap_ips_line) {
      my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
      $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
    }
    else {
      $growing_conditions = $cell_type;
    }

    print $fh join("\t",
      'ftp://ftp.sra.ebi.ac.uk/vol1/'.$file->{filename},
      $file->{checksum},
      $sample_name,
      @{$row}{qw(BIOSAMPLE_ID RUN_ID EXPERIMENT_ID)},
      $study_id,
      $row->{FIRST_CREATED},
      $cell_type,
      $source_material,
      $cgap_tissue->donor->gender || '',
      $growing_conditions || '',
      @{$row}{qw(INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_LAYOUT LIBRARY_STRATEGY LIBRARY_SOURCE LIBRARY_SELECTION PAIRED_NOMINAL_LENGTH)},
      $experiment_xml_hash->{EXPERIMENT}{DESIGN}{LIBRARY_DESCRIPTOR}{LIBRARY_CONSTRUCTION_PROTOCOL} || '',
    ), "\n";
  }

  close $fh;
}
