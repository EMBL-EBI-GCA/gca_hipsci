#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch);
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use XML::Simple qw(XMLin);
use Data::Compare qw(Compare);
use POSIX qw(strftime);
use Getopt::Long;
use Dumper;

my @era_params;
my $demographic_filename;
my %dataset_files;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $es_host='ves-hx-e3:9200';

GetOptions(
    'era_dbuser=s'  => \$era_params[0],
    'era_dbpass=s'  => \$era_params[1],
    'era_dbname=s'  => \$era_params[2],
    'dataset=s'     => \%dataset_files,
    'demographic_file=s' => \$demographic_filename,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'es_host=s' => \$es_host,
);


my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor;

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my $sql_study =  'select xmltype.getclobval(study_xml) study_xml from study where ega_id=?';
my $sth_study = $era_db->dbc->prepare($sql_study) or die "could not prepare $sql_study";

my %docs;
while (my ($dataset_id, $submission_file) = each %dataset_files) {
  print(1);
  print Dumper($dataset_id);
  print Dumper($submission_file);
  my $filename = fileparse($submission_file);
  my ($study_id) = $filename =~ /(EGAS\d+)/;
  die "did not recognise study_id from $submission_file" if !$study_id;

  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});

  my ($short_assay, $long_assay) = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /expression/i ? ('gexarray', 'Expression array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /HumanExome/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /methylation/i ? ('mtarray', 'Methylation array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /expression/i ? ('gexarray', 'Expression array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /HumanExome/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /methylation/i ? ('mtarray', 'Methylation array')
            : die "did not recognise assay for $study_id";
  my $disease = get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}) || get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION});
  die "did not recognise disease for $study_id" if !$disease;

  open my $in_fh, '<', $submission_file or die "could not open $submission_file $!";
  <$in_fh>;

  ROW:
  while (my $line = <$in_fh>) {
    my ($cell_line, $platform, $raw_file, undef, $signal_file, undef, $software, $genotype_file, undef, $additional_file) = split("\t", $line);
    my $cgap_ips_line = List::Util::first {$_->name eq $cell_line} @$cgap_ips_lines;
    my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                    : List::Util::first {$_->name eq $cell_line} @$cgap_tissues;
    die 'did not recognise sample '.$cell_line if !$cgap_tissue;

    my $sample_name = $cgap_ips_line ? $cgap_ips_line->name : $cgap_tissue->name;
    my $source_material = $cgap_tissue->tissue_type || '';
    my $cell_type = $cgap_ips_line ? 'iPSC'
                  : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                  : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                  : die "did not recognise source material $source_material";

    my @files = map {split(';', $_)} grep {$_} ($raw_file, $signal_file, $genotype_file, $additional_file);
    my @dates;
    foreach my $file (@files) {
      push(@dates, $file =~ /\.(\d{8})\./);
    }
    my ($date) = sort {$a <=> $b} @dates;

    my ($passage_number, $growing_conditions);
    if ($cgap_ips_line) {
      my $release_type = $short_assay eq 'mtarray' ? 'qc2' : 'qc1';
      my $cgap_release = $cgap_ips_line->get_release_for(type => $release_type, date =>$date);
      $growing_conditions = $cgap_release && $cgap_release->is_feeder_free ? 'Feeder-free'
                        : $cgap_release && !$cgap_release->is_feeder_free ? 'Feeder-dependent'
                        : $cell_line =~ /_\d\d$/ ? 'Feeder-free'
                        : $cgap_ips_line->passage_ips && $cgap_ips_line->passage_ips lt 20140000 ? 'Feeder-dependent'
                        : $cgap_ips_line->qc1 && $cgap_ips_line->qc1 lt 20140000 ? 'Feeder-dependent'
                        : die "could not get growing conditions for @files";
      if ($cgap_release) {
        $passage_number = $cgap_release->passage;
      }
    }
    else {
      $growing_conditions = $cell_type;
    }

    my %files;

    FILE:
    foreach my $filename (@files) {
      $filename =~ s/\.gpg$//;
      my ($ext) = $filename =~ /\.(\w+)(?:\.gz)?$/;
      next FILE if $ext eq 'tbi';
      my @files = grep {!$_->withdrawn && $_->name !~ m{/withdrawn/}} @{$fa->fetch_by_filename($filename)};
      if (!@files) {
        print "skipping $filename - did not recognise it\n";
        next FILE;
      }
      die "multiple files for $filename" if @files>1;

      my $file_description = $ext eq 'vcf' && $filename =~ /imputed_phased/ ?  'Imputed and phased genotypes'
                          : $ext eq 'vcf' || $ext eq 'gtc' ? 'Genotyping array calls'
                          : $ext eq 'idat' ? 'Array signal intensity data'
                          : $ext eq 'txt' && $short_assay eq 'mtarray' ? 'Text file with probe intensities'
                          : $ext eq 'txt' && $short_assay eq 'gexarray' && $software ? $software.' text file'
                          : die "did not recognise type of $filename";

      $files{$ext}{$file_description}{$filename} = $files[0];

    }

    while (my ($ext, $date_hash) = each %files) {

      while (my ($file_description, $file_hash) = each %{$files{$ext}}) {
        my $es_id = join('-', $sample_name, $short_assay, lc($file_description), $ext);
        $es_id =~ s/\s/_/g;

        #Hardfix of instrument for consistency
        if ($platform =~ /HumanCoreExome-12/){
          $platform = 'Illumina beadchip HumanCoreExome-12'
        }
        $docs{$es_id} = {
          description => $file_description,
          files => [
          ],
          archive => {
            name => 'EGA',
            accession => $dataset_id,
            accessionType => 'DATASET_ID',
            url => 'https://ega-archive.org/datasets/'.$dataset_id,
            ftpUrl => 'secure access via EGA',
            openAccess => 0,
          },
          samples => [{
            name => $cell_line,
            bioSamplesAccession => ($cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id),
            cellType => $cell_type,
            diseaseStatus => $disease,
            sex => $cgap_tissue->donor->gender,
            growingConditions => $growing_conditions,
          }],
          assay => {
            type => $long_assay,
            description => ["PLATFORM=$platform",],
            instrument => $platform
          }
        };
        if ($passage_number) {
          $docs{$es_id}{samples}[0]{passageNumber} = $passage_number;
        }
        while (my ($filename, $file_object) = each %$file_hash) {
          push(@{$docs{$es_id}{files}}, {name => $filename, md5 => $file_object->md5, type => $ext});
        }
      }
    }
  }

}
my $scroll = $elasticsearch->call('scroll_helper', (
  index => 'hipsci',
  type => 'file',
  search_type => 'scan',
  scroll => '5m',
  size => 500,
  body => {
    query => {
      filtered => {
        filter => {
          term => {
            'archive.name' => 'EGA',
          },
        }
      }
    }
  }
));

my $date = strftime('%Y%m%d', localtime);
ES_DOC:
while (my $es_doc = $scroll->next) {
  next ES_DOC if $es_doc->{_id} =~ /-ER[RZ]\d+$/;
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

