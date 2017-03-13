#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch);
use Getopt::Long;
use XML::Simple qw(XMLin);

my @era_params = ('ops$laura', undef, 'ERAPRO');
my @dataset_id;
my $demographic_filename;

GetOptions(
    'era_password=s'    => \$era_params[1],
    'dataset_id=s'    => \@dataset_id,
    'demographic_file=s' => \$demographic_filename,
);

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my $sql_dataset =  'select xmltype.getclobval(ega_dataset_xml) ega_dataset_xml from ega_dataset where ega_dataset_id=?';
my $sth_dataset = $era_db->dbc->prepare($sql_dataset) or die "could not prepare $sql_dataset";

my $sql_analysis =  "
  select a.analysis_id, to_char(sub.submission_date, 'YYYY-MM-DD') submission_date, xmltype.getclobval(a.analysis_xml) analysis_xml, s.biosample_id, s.sample_id
  from ega_dataset d, analysis_ega_dataset ad, sample s, analysis_sample ans, analysis a, submission sub
  where d.ega_dataset_id=ad.ega_dataset_id
  and ad.analysis_id=ans.analysis_id and s.sample_id=ans.sample_id
  and a.analysis_id=ad.analysis_id and a.submission_id=sub.submission_id
  and d.ega_dataset_id=?
  ";
my $sth_analysis = $era_db->dbc->prepare($sql_analysis) or die "could not prepare $sql_analysis";

my $sql_run =  "
  select r.run_id, to_char(r.first_created, 'YYYY-MM-DD') first_created
  from run_ega_dataset rd, run_sample rs, run r
  where rd.run_id=rs.run_id
  and r.run_id=rd.run_id
  and rs.sample_id=?
  and rd.ega_dataset_id=?
  ";
my $sth_run = $era_db->dbc->prepare($sql_run) or die "could not prepare $sql_run";

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);


foreach my $dataset_id (@dataset_id) {
  $sth_dataset->bind_param(1, $dataset_id);
  $sth_dataset->execute or die "could not execute";
  my $row = $sth_dataset->fetchrow_hashref;
  die "no dataset $dataset_id" if !$row;
  my $xml_hash = XMLin($row->{EGA_DATASET_XML});
  my $assay = $xml_hash->{DATASET}{TITLE} =~ /exome\W*seq/i ? 'exomeseq'
            : $xml_hash->{DATASET}{TITLE} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{DATASET}{DESCRIPTION} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{DATASET}{DESCRIPTION} =~ /exome\W*seq/i ? 'exomeseq'
            : die "did not recognise assay for $dataset_id";
  my $disease = get_disease_for_elasticsearch($xml_hash->{DATASET}{TITLE}) || get_disease_for_elasticsearch($xml_hash->{DATASET}{DESCRIPTION});
  die "did not recognise disease for $dataset_id" if !$disease;
  my $filename_disease = lc($disease);
  $filename_disease =~ s{[ -]}{_}g;

  my $output = join('.', 'EGA', $dataset_id, $assay, $filename_disease, 'analysis_files', 'tsv');
  open my $fh, '>', $output or die "could not open $output $!";
  print $fh '##EGA dataset title: ', $xml_hash->{DATASET}{TITLE}, "\n";
  print $fh "##EGA dataset ID: $dataset_id\n";
  print $fh '##Assay: ', ($assay eq 'exomeseq' ? 'Exome-seq' : $assay eq 'rnaseq' ? 'RNA-seq' : die "did not recognise assay $assay"), "\n";
  print $fh "##Disease cohort: $disease\n";
  print $fh '#', join("\t", qw(
    filename md5 cell_line biosample_id analysis_id description archive_submission_date cell_type source_material sex growing_conditions
  )), "\n";


  $sth_analysis->bind_param(1, $dataset_id);
  $sth_analysis->execute or die "could not execute";

  ROW:
  while (my $row = $sth_analysis->fetchrow_hashref) {

    my $xml_hash = XMLin($row->{ANALYSIS_XML});
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

    my $files = $xml_hash->{ANALYSIS}{FILES}{FILE};
    $files = ref($files) eq 'ARRAY' ? $files : [$files];

    $sth_run->bind_param(1, $row->{SAMPLE_ID});
    $sth_run->bind_param(2, $dataset_id);
    $sth_run->execute or die "could not execute";
    my $run_rows = $sth_run->fetchall_arrayref;
    die 'no run objects for '.$row->{BIOSAMPLE_ID} if !@$run_rows;
    my $run_time = DateTime::Format::ISO8601->parse_datetime($run_rows->[0][1])->subtract(days => 90);
    my $growing_conditions;
    if ($cgap_ips_line) {
      my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
      $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
    }
    else {
      $growing_conditions = $cell_type;
    }

    FILE:
    foreach my $file (@$files) {
      next FILE if $file->{filetype} eq 'bai';
      next FILE if $file->{filetype} eq 'tbi';
      $file->{filename} =~ s/\.gpg$//;
      print $fh join("\t",
        @{$file}{qw(filename unencrypted_checksum)},
        $sample_name,
        $row->{BIOSAMPLE_ID},
        $row->{ANALYSIS_ID},
        $xml_hash->{ANALYSIS}{DESCRIPTION},
        $row->{SUBMISSION_DATE},
        $cell_type,
        $source_material,
        $cgap_tissue->donor->gender || '',
        $growing_conditions || '',
      ), "\n";
    }
  }

  close $fh;
}
