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
use Data::Dumper;


my @era_params;
my @dataset_id;
my $demographic_filename;
my $es_host='ves-hx-e3:9200';
my %dataset_files;
use Data::Dumper;


GetOptions(
    'era_dbuser=s'  => \$era_params[0],
    'era_dbpass=s'  => \$era_params[1],
    'era_dbname=s'  => \$era_params[2],
    'dataset=s'     => \%dataset_files,
    'dataset_id=s'    => \@dataset_id,
    'demographic_file=s' => \$demographic_filename,
    'es_host=s' => \$es_host,
);

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my $sql_dataset =  'select xmltype.getclobval(ega_dataset_xml) ega_dataset_xml from ega_dataset where ega_dataset_id=?';
print Dumper($sql_dataset);
# my $sth_dataset = $era_db->dbc->prepare($sql_dataset) or die "could not prepare $sql_dataset";
#
# my $sql_analysis =  "
#   select a.analysis_id, to_char(sub.submission_date, 'YYYY-MM-DD') submission_date, xmltype.getclobval(a.analysis_xml) analysis_xml, s.biosample_id, s.sample_id
#   from ega_dataset d, analysis_ega_dataset ad, sample s, analysis_sample ans, analysis a, submission sub
#   where d.ega_dataset_id=ad.ega_dataset_id
#   and ad.analysis_id=ans.analysis_id and s.sample_id=ans.sample_id
#   and a.analysis_id=ad.analysis_id and a.submission_id=sub.submission_id
#   and d.ega_dataset_id=?
#   ";
# my $sth_analysis = $era_db->dbc->prepare($sql_analysis) or die "could not prepare $sql_analysis";
#
# my $sql_run =  "
#   select r.run_id, to_char(r.first_created, 'YYYY-MM-DD') first_created, e.instrument_platform, e.instrument_model, e.library_layout, e.library_strategy, e.library_source, e.library_selection, e.paired_nominal_length, xmltype.getclobval(e.experiment_xml) experiment_xml
#   from run_ega_dataset rd, run_sample rs, run r, experiment e
#   where rd.run_id=rs.run_id
#   and r.run_id=rd.run_id
#   and r.experiment_id=e.experiment_id
#   and rs.sample_id=?
#   and rd.ega_dataset_id=?
#   ";
# my $sth_run = $era_db->dbc->prepare($sql_run) or die "could not prepare $sql_run";
#
# my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
# improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);
#
# my %docs;
# foreach my $dataset_id (@dataset_id) {
#   $sth_dataset->bind_param(1, $dataset_id);
#   $sth_dataset->execute or die "could not execute";
#   my $row = $sth_dataset->fetchrow_hashref;
#   die "no dataset $dataset_id" if !$row;
#   my $xml_hash = XMLin($row->{EGA_DATASET_XML});
#   # print Dumper($xml_hash);
#   my ($short_assay, $long_assay) = $xml_hash->{DATASET}{TITLE} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
#             : $xml_hash->{DATASET}{TITLE} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
#             : $xml_hash->{DATASET}{DESCRIPTION} =~ /rna\W*seq/i ? ('rnaseq', 'RNA-seq')
#             : $xml_hash->{DATASET}{DESCRIPTION} =~ /exome\W*seq/i ? ('exomeseq', 'Exome-seq')
#             : die "did not recognise assay for $dataset_id";
#   my $disease = get_disease_for_elasticsearch($xml_hash->{DATASET}{TITLE}) || get_disease_for_elasticsearch($xml_hash->{DATASET}{DESCRIPTION});
#   # print "$disease\n";
#   die "did not recognise disease for $dataset_id" if !$disease;
#
#   $sth_analysis->bind_param(1, $dataset_id);
#   $sth_analysis->execute or die "could not execute";
#
#   ROW:
#   while (my $row = $sth_analysis->fetchrow_hashref) {
#
#     my $xml_hash = XMLin($row->{ANALYSIS_XML});
#     my $cgap_ips_line = List::Util::first {$_->biosample_id && $_->biosample_id eq $row->{BIOSAMPLE_ID}} @$cgap_ips_lines;
#     my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
#                     : List::Util::first {$_->biosample_id eq $row->{BIOSAMPLE_ID}} @$cgap_tissues;
#     die 'did not recognise sample '.$row->{BIOSAMPLE_ID} if !$cgap_tissue;
#
#     my $sample_name = $cgap_ips_line ? $cgap_ips_line->name : $cgap_tissue->name;
#     my $source_material = $cgap_tissue->tissue_type || '';
#     my $cell_type = $cgap_ips_line ? 'iPSC'
#                   : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
#                   : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
#                   : die "did not recognise source material $source_material";
#
#     my $files = $xml_hash->{ANALYSIS}{FILES}{FILE};
#     $files = ref($files) eq 'ARRAY' ? $files : [$files];
#     $files = [grep {$_->{filetype} ne 'bai' && $_->{filetype} ne 'tabix'} @$files];
#
#     $sth_run->bind_param(1, $row->{SAMPLE_ID});
#     $sth_run->bind_param(2, $dataset_id);
#     $sth_run->execute or die "could not execute";
#     my $run_row = $sth_run->fetchrow_hashref;
#     my $run_time = $run_row ? DateTime::Format::ISO8601->parse_datetime($run_row->{FIRST_CREATED})->subtract(days => 90) : undef;
#     my $experiment_xml_hash = $run_row ? XMLin($run_row->{EXPERIMENT_XML}) : {};
#     my ($growing_conditions, $passage_number);
#     if ($cgap_ips_line) {
#       if ($run_time) {
#         my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$run_time->ymd);
#         $growing_conditions = $cgap_release->is_feeder_free ? 'Feeder-free' : 'Feeder-dependent';
#         $passage_number = $cgap_release->passage;
#       }
#     }
#     else {
#       $growing_conditions = $cell_type;
#     }
#
#     my $description = $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{REFERENCE_ALIGNMENT} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bstar\b/i ? 'Splice-aware STAR alignment'
#                     : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{REFERENCE_ALIGNMENT} ? 'BWA alignment'
#                     : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bimputed\b/i ? 'Imputed and phased genotypes'
#                     : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{SEQUENCE_VARIATION} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bmpileup\b/i ? 'mpileup variant calls'
#                     : $xml_hash->{ANALYSIS}{ANALYSIS_TYPE}{PROCESSED_READS} && $xml_hash->{ANALYSIS}{DESCRIPTION} =~ /\bkallisto\b/i ? 'Abundances of transcripts'
#                     : die 'did not derive a file description for '.$row->{ANALYSIS_ID};
#
#     my $es_id = join('-', $sample_name, $short_assay, $row->{ANALYSIS_ID});
#     $es_id =~ s/\s/_/g;
#
#
#     $docs{$es_id} = {
#       description => $description,
#       files => [
#       ],
#       archive => {
#         name => 'EGA',
#         accession => $dataset_id,
#         accessionType => 'DATASET_ID',
#         url => 'https://ega-archive.org/datasets/'.$dataset_id,
#         ftpUrl => 'secure access via EGA',
#         openAccess => 0,
#       },
#       samples => [{
#         name => $sample_name,
#         bioSamplesAccession => $row->{BIOSAMPLE_ID},
#         cellType => $cell_type,
#         diseaseStatus => $disease,
#         sex => $cgap_tissue->donor->gender,
#         growingConditions => $growing_conditions,
#       }],
#       assay => {
#         type => $long_assay,
#         description => $run_row ? [ map {$_.'='.$run_row->{$_}}  qw(INSTRUMENT_PLATFORM INSTRUMENT_MODEL LIBRARY_LAYOUT LIBRARY_STRATEGY LIBRARY_SOURCE LIBRARY_SELECTION PAIRED_NOMINAL_LENGTH)] : [],
#         instrument => $run_row ? $run_row->{INSTRUMENT_MODEL} : undef,
#       }
#     };
#     if (my $exp_protocol = $experiment_xml_hash->{DESIGN}{LIBRARY_DESCRIPTOR}{LIBRARY_CONSTRUCTION_PROTOL}) {
#       push(@{$docs{$es_id}{assay}{description}}, $exp_protocol);
#     }
#     if ($passage_number) {
#       $docs{$es_id}{samples}[0]{passageNumber} = $passage_number;
#     }
#     FILE:
#     foreach my $file (@$files) {
#       my $filename = fileparse($file->{filename});
#       $filename =~ s/\.gpg$//;
#       push(@{$docs{$es_id}{files}},
#           {
#             name => $filename,
#             md5 => $file->{unencrypted_checksum},
#             type => $file->{filetype},
#           }
#         );
#     }
#   }
#
# }
# my $scroll = $elasticsearch->call('scroll_helper', (
#   index => 'hipsci',
#   type => 'file',
#   search_type => 'scan',
#   size => 500,
#   body => {
#     query => {
#       filtered => {
#         filter => {
#           term => {
#             'archive.name' => 'EGA',
#           },
#         }
#       }
#     }
#   }
# ));
#
# my $date = strftime('%Y%m%d', localtime);
# ES_DOC:
# while (my $es_doc = $scroll->next) {
#   next ES_DOC if $es_doc->{_id} !~ /-ERZ\d+$/;
#   my $new_doc = $docs{$es_doc->{_id}};
#   if (!$new_doc) {
#     printf("curl -XDELETE http://%s/%s/%s/%s\n", $es_host, @$es_doc{qw(_index _type _id)});
#     next ES_DOC;
#   }
#   delete $docs{$es_doc->{_id}};
#   my ($created, $updated) = @{$es_doc->{_source}}{qw(_indexCreated _indexUpdated)};
#   $new_doc->{_indexCreated} = $es_doc->{_source}{_indexCreated} || $date;
#   $new_doc->{_indexUpdated} = $es_doc->{_source}{_indexUpdated} || $date;
#   next ES_DOC if Compare($new_doc, $es_doc->{_source});
#   $new_doc->{_indexUpdated} = $date;
#   $elasticsearch->index_file(id => $es_doc->{_id}, body => $new_doc);
# }
# while (my ($es_id, $new_doc) = each %docs) {
#   $new_doc->{_indexCreated} = $date;
#   $new_doc->{_indexUpdated} = $date;
#   $elasticsearch->index_file(body => $new_doc, id => $es_id);
# }
#
