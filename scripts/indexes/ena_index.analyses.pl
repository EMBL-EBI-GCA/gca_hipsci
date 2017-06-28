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
my @sequencing_study_id;
my %analysis_study_id;
my $demographic_filename;

GetOptions(
    'era_password=s'    => \$era_params[1],
    'study_id=s'    => \@sequencing_study_id,
    'analysis_study_id=s'    => \%analysis_study_id,
    'demographic_file=s' => \$demographic_filename,
);

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my $sql_study =  'select xmltype.getclobval(study_xml) study_xml from study where study_id=?';
my $sth_study = $era_db->dbc->prepare($sql_study) or die "could not prepare $sql_study";

my $sql_analysis =  "
  select a.analysis_id, to_char(sub.submission_date, 'YYYY-MM-DD') submission_date, xmltype.getclobval(a.analysis_xml) analysis_xml, s.biosample_id, s.sample_id
  from sample s, analysis_sample ans, analysis a, submission sub
  where s.sample_id=ans.sample_id and ans.analysis_id=a.analysis_id
  and a.submission_id=sub.submission_id
  and a.status_id=4
  and a.study_id=?
  ";
my $sth_analysis = $era_db->dbc->prepare($sql_analysis) or die "could not prepare $sql_analysis";

my $sql_run =  "
  select r.run_id, to_char(r.first_created, 'YYYY-MM-DD') first_created
  from run_sample rs, run r, experiment e
  where r.run_id=rs.run_id
  and r.status_id=4
  and rs.sample_id=?
  and e.study_id=?
  ";
my $sth_run = $era_db->dbc->prepare($sql_run) or die "could not prepare $sql_run";

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

foreach my $study_id (@sequencing_study_id, keys %analysis_study_id) {
  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});
  my $assay = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /exome\W*seq/i ? 'exomeseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /genotyping\W*array/i ? 'gtarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /whole\W*genome\W*sequencing/i ? 'wgs'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /rna\W*seq/i ? 'rnaseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /exome\W*seq/i ? 'exomeseq'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /genotyping\W*array/i ? 'gtarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /whole\W*genome\W*sequencing/i ? 'wgs'
            : die "did not recognise assay for $study_id";
  my $disease = get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}) || get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION});
  if (!$disease && $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /ipsc_reference_set/i) {
    $disease = get_disease_for_elasticsearch('normal');
  }
  die "did not recognise disease for $study_id" if !$disease;
  my $filename_disease = lc($disease);
  $filename_disease =~ s{[ -]}{_}g;

  my $output = join('.', 'ENA', $study_id, $assay, $filename_disease, 'analysis_files', 'tsv');
  open my $fh, '>', $output or die "could not open $output $!";
  print $fh '##ENA study title: ', $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}, "\n";
  print $fh "##ENA study ID: $study_id\n";
  print $fh '##Assay: ', ($assay eq 'exomeseq' ? 'Exome-seq' : $assay eq 'rnaseq' ? 'RNA-seq' : $assay eq 'gtarray' ? 'Genotyping array' : $assay eq 'wgs' ? 'Whole genome sequencing' :  die "did not recognise assay $assay"), "\n";
  print $fh "##Disease cohort: $disease\n";
  print $fh '#', join("\t", qw(
    file_url md5 cell_line biosample_id analysis_id description archive_submission_date cell_type source_material sex growing_conditions
  )), "\n";


  $sth_analysis->bind_param(1, $study_id);
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

    my $growing_conditions;
    if ($cgap_ips_line) {
      if ($assay =~ /seq$/ || $assay eq 'wgs') {
        my $run_study_id = $analysis_study_id{$study_id} || $study_id;
        $sth_run->bind_param(1, $row->{SAMPLE_ID});
        $sth_run->bind_param(2, $run_study_id);
        $sth_run->execute or die "could not execute";
        my $run_rows = $sth_run->fetchall_arrayref;
        next ROW if !@$run_rows;
        my $run_time = DateTime::Format::ISO8601->parse_datetime($run_rows->[0][1])->subtract(days => 90);
        my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
        die "no qc2 cgap release for $sample_name" if !$cgap_release;
        $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
      }
      else {
        my @dates;
        FILE:
        foreach my $filename (map {$_->{filename}} @$files) {
          my ($date) = $filename =~ /\.(\d{8})\./;
          next FILE if !$date;
          push(@dates, $date);
        }
        die "no file dates" if ! scalar @dates;
        my ($filedate) = sort {$a <=> $b} @dates;
        my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc1', date =>$filedate);
        $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
      }
    }
    else {
      $growing_conditions = $cell_type;
    }


    FILE:
    foreach my $file (@$files) {
      next FILE if $file->{filetype} eq 'bai';
      next FILE if $file->{filetype} eq 'tbi';
      next FILE if $file->{filetype} eq 'tabix';
      next FILE if $file->{filename} =~ /\.ped$/;

      my $filename = $file->{filename};
      $filename =~ s{.*/}{};

      print $fh join("\t",
        sprintf('ftp://ftp.sra.ebi.ac.uk/vol1/%s/%s/%s', substr($row->{ANALYSIS_ID}, 0, 6), $row->{ANALYSIS_ID}, $filename),
        $file->{checksum},
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
