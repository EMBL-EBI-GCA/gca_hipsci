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
use Data::Dumper;

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
  # print Dumper($dataset_id); # 'EGAD00010001147'
  # print Dumper($submission_file); # '/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.20161212.txt'
  my $filename = fileparse($submission_file);
  # print Dumper($filename); #  'EGAS00001000866.gtarray.20161212.txt'
  my ($study_id) = $filename =~ /(EGAS\d+)/;
  die "did not recognise study_id from $submission_file" if !$study_id;
  # print Dumper($study_id); # 'EGAS00001000866', 'EGAS00001000867'  but not in order of arguments in bash file.
  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});
  # print Dumper($xml_hash);
  # {
  #         'STUDY' => {
  #                    'DESCRIPTOR' => {
  #                                    'STUDY_ABSTRACT' => 'The HipSci project brings together diverse constituents in genomics, proteomics, cell biology and clinical genetics to create a UK national iPS cell resource and use it to carry out cellular genetic studies. In this sub-study we performed Expression analysis using the Illumina HumanHT -12 Expression BeadChip on iPS cells generated from skin biopsies from healthy volunteers.',
  #                                    'STUDY_TITLE' => 'HipSci HumanHT_12v4 Expression BeadChip analysis-Healthy volunteers',
  #                                    'STUDY_TYPE' => {
  #                                                    'existing_study_type' => 'Other'
  #                                                  },
  #                                    'STUDY_DESCRIPTION' => 'The HipSci project brings together diverse constituents in genomics, proteomics, cell biology and clinical genetics to create a UK national iPS cell resource and use it to carry out cellular genetic studies. In this sub-study we performed Expression analysis using the Illumina HumanHT -12 Expression BeadChip on iPS cells generated from skin biopsies from healthy volunteers.'
  #                                  },
  #                    'center_name' => 'SC',
  #                    'IDENTIFIERS' => {
  #                                     'SUBMITTER_ID' => {
  #                                                       'namespace' => 'SC',
  #                                                       'content' => 'ena-STUDY-SC-18-06-2014-10:51:13:740-505'
  #                                                     },
  #                                     'PRIMARY_ID' => 'ERP006106'
  #                                   },
  #                    'alias' => 'ena-STUDY-SC-18-06-2014-10:51:13:740-505',
  #                    'accession' => 'ERP006106',
  #                    'broker_name' => 'EGA'
  #                  }
  #       };

  #
  my ($short_assay, $long_assay) = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /expression/i ? ('gexarray', 'Expression array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /HumanExome/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /methylation/i ? ('mtarray', 'Methylation array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /expression/i ? ('gexarray', 'Expression array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /HumanExome/i ? ('gtarray', 'Genotyping array')
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /methylation/i ? ('mtarray', 'Methylation array')
            : die "did not recognise assay for $study_id";
  # print Dumper($short_assay); # gtarray
  my $disease = get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}) || get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION});
  die "did not recognise disease for $study_id" if !$disease;
  # print($disease); # Normal Normal Bardet-Biedl syndrome Monogenic diabetes
  open my $in_fh, '<', $submission_file or die "could not open $submission_file $!";
  <$in_fh>;

  ROW:
  while (my $line = <$in_fh>) { # require new files so it adds new EGA datasets, some might be aempty
    print Dumper($line); # lines in the dataset files.
    my ($cell_line, $platform, $raw_file, undef, $signal_file, undef, $software, $genotype_file, undef, $additional_file) = split("\t", $line);
    # print Dumper($cell_line); # 'HPSI0414i-rauj_1'
    # print Dumper($platform); # 'HumanCoreExome-12 v1.0'
    # print Dumper($raw_file); # 'HPSI0414i-rauj_1.HumanCoreExome-12_v1_0.9723038134_R02C01_Grn.gtarray.20141111.idat;HPSI0414i-rauj_1.HumanCoreExome-12_v1_0.9723038134_R02C01.gtarray.20141111.gtc;HPSI0414i-rauj_1.HumanCoreExome-12_v1_0.9723038134_R02C01_Red.gtarray.20141111.idat'
    # print Dumper($signal_file); # .. empty
    # print Dumper($software); # .. empty
    # print Dumper($genotype_file); # 'HPSI0414i-rauj_1.wec.gtarray.HumanCoreExome-12_v1_0.20141111.genotypes.vcf.gz;HPSI0414i-rauj_1.wec.gtarray.HumanCoreExome-12_v1_0.20141111.genotypes.vcf.gz.tbi'
    # print Dumper($additional_file); # 'HPSI0414i-rauj_1.wec.gtarray.HumanCoreExome-12_v1_0.imputed_phased.20150604.genotypes.vcf.gz;HPSI0414i-rauj_1.wec.gtarray.HumanCoreExome-12_v1_0.imputed_phased.20150604.genotypes.vcf.gz.tbi'
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
  #
    my @files = map {split(';', $_)} grep {$_} ($raw_file, $signal_file, $genotype_file, $additional_file);
    # file names in each file
    my @dates;
    foreach my $file (@files) {
      push(@dates, $file =~ /\.(\d{8})\./);
    }

    my ($date) = sort {$a <=> $b} @dates;
    # print Dumper($date); # '20160304' # this is th eother one that is recieved from the actual files
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
      # print Dumper($filename); # returns the files names, whichever ones that exist, $raw_file, $signal_file, $genotype_file, $additional_file
      my ($ext) = $filename =~ /\.(\w+)(?:\.gz)?$/;
      print Dumper($ext);
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
# my $scroll = $elasticsearch->call('scroll_helper', (
#   index => 'hipsci',
#   type => 'file',
#   search_type => 'scan',
#   scroll => '5m',
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
#   next ES_DOC if $es_doc->{_id} =~ /-ER[RZ]\d+$/;
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
