#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch);
use Getopt::Long;
use XML::Simple qw(XMLin);
use Data::Compare qw(Compare);
use POSIX qw(strftime);
use File::Basename qw(fileparse);
use URI::Escape qw(uri_escape);

my @era_params = ('ops$laura', undef, 'ERAPRO');
my @study_id;
my $demographic_filename;
my $es_host='ves-hx-e3:9200';

GetOptions(
    'era_password=s'    => \$era_params[1],
    'study_id=s'    => \@study_id,
    'demographic_file=s' => \$demographic_filename,
    'es_host=s' => \$es_host,
);

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

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

my %docs;
foreach my $study_id (@study_id) {
  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});
  my ($short_assay, $long_assay) = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /whole\W*genome\W*sequencing/i ? ('wgs', 'Whole genome sequencing')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /whole\W*genome\W*sequencing/i ? ('wgs', 'Whole genome sequencing')
            : die "did not recognise assay for $study_id";
  my $disease = get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}) || get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION});
  if (!$disease && $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /ipsc_reference_set/i) {
    $disease = get_disease_for_elasticsearch('normal');
  }
  die "did not recognise disease for $study_id" if !$disease;

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
    my ($growing_conditions, $passage_number);
    if ($cgap_ips_line) {
      my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
      die "no qc2 cgap release for $sample_name" if !$cgap_release;
      $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
      $passage_number = $cgap_release->passage;
    }
    else {
      $growing_conditions = $cell_type;
    }

    my ($filename, $dirname) = fileparse($file->{filename});
    my $file_description = 'Raw sequencing reads';

    my $es_id = join('-', $sample_name, $short_assay, $row->{RUN_ID});
    $es_id =~ s/\s/_/g;

    $docs{$es_id} = {
      description => 'Raw sequencing reads',
      files => [
        {
          name => $filename,
          md5 => $file->{checksum},
          type => $file->{filetype},
        }
      ],
      archive => {
        name => 'ENA',
        accession => $row->{RUN_ID},
        accessionType => 'RUN_ID',
        url => 'http://www.ebi.ac.uk/ena/data/view/'.$row->{RUN_ID},
        ftpUrl => sprintf('ftp://ftp.sra.ebi.ac.uk/vol1/%s%s', $dirname, uri_escape($filename)),
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
        description => [ map {$_.'='.$row->{$_}}  qw(INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_LAYOUT LIBRARY_STRATEGY LIBRARY_SOURCE LIBRARY_SELECTION PAIRED_NOMINAL_LENGTH)],
        instrument => $row->{INSTRUMENT_MODEL}
      }
    };
    if ($passage_number) {
      $docs{$es_id}{samples}[0]{passageNumber} = $passage_number;
    }
    if (my $exp_protocol = $experiment_xml_hash->{DESIGN}{LIBRARY_DESCRIPTOR}{LIBRARY_CONSTRUCTION_PROTOL}) {
      push(@{$docs{$es_id}{assay}{description}}, $exp_protocol);
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
              'file.accessionType' => 'RUN_ID',
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

