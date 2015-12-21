#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Getopt::Long;
use XML::Simple qw(XMLin);
use Data::Compare qw(Compare);
use POSIX qw(strftime);
use File::Basename qw(fileparse);

my @era_params = ('ops$laura', undef, 'ERAPRO');
my @sequencing_study_id;
my %analysis_study_id;
my $demographic_filename;
my $es_host='ves-hx-e3:9200';

GetOptions(
    'era_password=s'    => \$era_params[1],
    'sequencing_study_id=s'    => \@sequencing_study_id,
    'analysis_study_id=s'    => \%analysis_study_id,
    'demographic_file=s' => \$demographic_filename,
    'es_host=s' => \$es_host,
);

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

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
  select r.run_id, to_char(r.first_created, 'YYYY-MM-DD') first_created, e.instrument_platform, e.instrument_model, e.library_layout, e.library_strategy, e.library_source, e.library_selection, e.paired_nominal_length, xmltype.getclobval(e.experiment_xml) experiment_xml
  from run_sample rs, run r, experiment e
  where r.run_id=rs.run_id
  and r.status_id=4
  and rs.sample_id=?
  and e.study_id=?
  ";
my $sth_run = $era_db->dbc->prepare($sql_run) or die "could not prepare $sql_run";

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my %docs;
foreach my $study_id (@sequencing_study_id, keys %analysis_study_id) {
  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});
  my ($short_assay, $long_assay) = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /genotyping\W*array/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /whole\W*genome\W*sequencing/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /genotyping\W*array/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /whole\W*genome\W*sequencing/i ? ('wgs', 'Whole genome sequencing')
            : die "did not recognise assay for $study_id";
  my $disease = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /healthy/i ? 'Normal'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrom'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /diabetes/i ? 'Monogenic diabetes'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /reference_set/i ? 'Normal'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /healthy/i ? 'Normal'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrome'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /diabetes/i ? 'Monogenic diabetes'
            : die "did not recognise disease for $study_id";

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
    $files = [grep {$_->{filetype} ne 'bai' && $_->{filetype} ne 'tabix' && $_->{filetype} ne 'tbi'} @$files];

    if ($row->{ANALYSIS_ID} eq 'ERZ127336' || $row->{ANALYSIS_ID} eq 'ERZ127571') {
      $files = [grep {$_->{filename} !~ /\.ped/} @$files];
    }

    my ($growing_conditions, $assay_description, $exp_protocol);
    if ($short_assay =~ /seq$/ || $short_assay eq 'wgs' ) {
      my $run_study_id = $analysis_study_id{$study_id} || $study_id;
      $sth_run->bind_param(1, $row->{SAMPLE_ID});
      $sth_run->bind_param(2, $run_study_id);
      $sth_run->execute or die "could not execute";
      my $run_row = $sth_run->fetchrow_hashref;
      die 'no run objects for '.$row->{BIOSAMPLE_ID} if !$run_row;
      my $run_time = DateTime::Format::ISO8601->parse_datetime($run_row->{FIRST_CREATED})->subtract(days => 90);
      my $experiment_xml_hash = XMLin($run_row->{EXPERIMENT_XML});
      $assay_description = [ map {$_.'='.$run_row->{$_}}  qw(INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_LAYOUT LIBRARY_STRATEGY LIBRARY_SOURCE LIBRARY_SELECTION PAIRED_NOMINAL_LENGTH)];

      if ($cgap_ips_line) {
        my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
        $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
      }
      else {
        $growing_conditions = $cell_type;
      }

      $exp_protocol = $experiment_xml_hash->{DESIGN}{LIBRARY_DESCRIPTOR}{LIBRARY_CONSTRUCTION_PROTOL};
    }
    else {
      if ($cgap_ips_line) {
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
      else {
        $growing_conditions = $cell_type;
      }
      if (my $platform = $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION}{PLATFORM}) {
        $assay_description = ["PLATFORM=$platform"];
      }
    }

    my $description = $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{REFERENCE_ALIGNMENT} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bstar\b/i ? 'Splice-aware STAR alignment'
                    : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{REFERENCE_ALIGNMENT} ? 'BWA alignment'
                    : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bimputed\b/i ? 'Imputed and phased genotypes'
                    : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bmpileup\b/i ? 'mpileup variant calls'
                    : $short_assay eq 'gtarray' && $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bGenotype calls\b/i ? 'Genotyping array calls'
                    : die 'did not derive a file description for '.$row->{ANALYSIS_ID};

    my $es_id = join('-', $sample_name, $short_assay, $row->{ANALYSIS_ID});
    $es_id =~ s/\s/_/g;

    $docs{$es_id} = {
      description => $description,
      files => [
      ],
      archive => {
        name => 'ENA',
        accession => $row->{ANALYSIS_ID},
        accessionType => 'ANALYSIS_ID',
        url => 'http://www.ebi.ac.uk/ena/data/view/'.$row->{ANALYSIS_ID},
        ftpUrl => sprintf('ftp://ftp.sra.ebi.ac.uk/vol1/%s/%s/', substr($row->{ANALYSIS_ID}, 0, 6), $row->{ANALYSIS_ID}),
        openAccess => 1,
      },
      samples => [{
        name => $sample_name,
        bioSamplesAccession => $row->{BIOSAMPLE_ID},
        cellType => $cell_type,
        diseaseStatus => $disease,
        sex => $cgap_tissue->donor->gender,
        growingConditions => $growing_conditions,
      }],
      assay => {
        type => $long_assay,
      }
    };
    if ($assay_description) {
      $docs{$es_id}{assay}{description} = $assay_description;
    }
    if ($exp_protocol) {
      push(@{$docs{$es_id}{assay}{description}}, $exp_protocol);
    }

    FILE:
    foreach my $file (@$files) {
      my $filename = fileparse($file->{filename});
      push(@{$docs{$es_id}{files}}, 
          {
            name => $filename,
            md5 => $file->{checksum},
            type => $file->{filetype},
          }
        );
    }

  }

}
my $scroll = $elasticsearch->call('scroll_helper', (
  index => 'hipsci',
  type => 'file',
  search_type => 'scan',
  size => 500,
  body => {
    query => {
      filtered => {
        filter => {
          and => [
            {term => {
              'archive.name' => 'ENA',
            }},
            {term => {
              'file.accessionType' => 'ANALYSIS_ID',
            }}
          ]
        }
      }
    }
  }
));

my $date = strftime('%Y%m%d', localtime);
ES_DOC:
while (my $es_doc = $scroll->next) {
  my $new_doc = $docs{$es_doc->{_id}};
  if (!$new_doc) {
    printf("curl -XDELETE http://%s/%s/%s/%s\n", $es_host, @$es_doc{qw(_index _type _id)});
    next ES_DOC;
  }
  delete $docs{$es_doc->{_id}};
  my ($created, $updated) = @{$es_doc->{_source}}{qw(_indexCreated _indexUpdated)};
  $new_doc->{_indexCreated} = $es_doc->{_source}{_indexCreated} || $date;
  $new_doc->{_indexUpdated} = $es_doc->{_source}{_indexUpdated} || $date;
  next ES_DOC if Compare($new_doc, $es_doc->{_source});
  $new_doc->{_indexUpdated} = $date;
  $elasticsearch->index_file(id => $es_doc->{_id}, body => $new_doc);
}
while (my ($es_id, $new_doc) = each %docs) {
  $new_doc->{_indexCreated} = $date;
  $new_doc->{_indexUpdated} = $date;
  $elasticsearch->index_file(body => $new_doc, id => $es_id);
}

