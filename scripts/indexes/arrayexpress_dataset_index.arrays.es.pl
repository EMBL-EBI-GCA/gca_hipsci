#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use Data::Compare qw(Compare);
use LWP::Simple;
use POSIX qw(strftime);
use Getopt::Long;


my $dataset_id;
my $outfolder;
my $demographic_filename;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
#NOTE: Don't use password with g1kro so leave undef
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $es_host='ves-hx-e3:9200';

my $short_assay;
my $long_assay;
my $disease;
my $study_title;
my $platform;

GetOptions(
    'dataset_id=s'    => \$dataset_id,
    'outfolder=s'    => \$outfolder,
    'demographic_file=s'  => \$demographic_filename,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
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

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my $sdrf = "http://www.ebi.ac.uk/arrayexpress/files/".$dataset_id."/".$dataset_id.".sdrf.txt";
my $idf = "http://www.ebi.ac.uk/arrayexpress/files/".$dataset_id."/".$dataset_id.".idf.txt";

my $idf_file = get $idf;
open( IDF, '<', \$idf_file );
while (my $line = <IDF>) {
  if ($line =~/^Investigation Title/){
    my @parts = split("\t", $line);
    $study_title = $parts[1];
    ($short_assay, $long_assay) = $study_title =~ /methylation/i ? ('mtarray', 'Methylation array')
          : $study_title =~ /HumanExome/i ? ('gtarray', 'Genotyping array')
          : $study_title =~ /expression/i ? ('gexarray', 'Expression array')
          : die "did not recognise assay for $study_title";
    $platform = $study_title =~ /HumanHT 12v4/i ? 'HumanHT-12 v4'
          : $study_title =~ /Illumina 450K Methylation/i ? 'HumanMethylation450'
          : die "did not recognise platform for $study_title";
  }
}
close(IDF);

my $sdrf_file = get $sdrf;
open( SDRF, '<', \$sdrf_file );

my %arrayexpress;
my @sdrflines = <SDRF>;
shift(@sdrflines);  # Remove title line
if ($short_assay eq 'gexarray'){
  foreach my $line (@sdrflines) {
    my @parts = split("\t", $line);
    my $cellline = $parts[0];
    my $raw_ftp_link = $parts[33];
    my $raw_file = $parts[32];
    my $processed_ftp_link = $parts[36];
    my $processed_file = $parts[35];
    $processed_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;  
    $raw_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;
    $disease = $parts[8] =~ /norm/i ? 'Normal'
          : $parts[8] =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrom'
          : $parts[8] =~ /diabetes/i ? 'Monogenic diabetes'
          : die "did not recognise disease for $dataset_id";
    $arrayexpress{$cellline} = [$raw_ftp_link."/".$raw_file, $processed_ftp_link."/".$processed_file];
  }
}elsif($short_assay eq 'mtarray'){
  foreach my $line (@sdrflines) {
    my @parts = split("\t", $line);
    my $cellline = $parts[0];
    my $mt_ftp_link = $parts[35];
    my $mt_file = $parts[34];
    $mt_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;
    #Get specific methylation version
    $platform = $mt_file =~ /HumanMethylation450v1/i ? 'HumanMethylation450 v1'
          : die "did not recognise platform for $study_title in file $mt_file";
    $disease = $parts[8] =~ /normal/i ? 'Normal'
          : $parts[8] =~ /bardet\W*biedl/i ? 'Bardet-Biedl syndrom'
          : $parts[8] =~ /diabetes/i ? 'Monogenic diabetes'
          : die "did not recognise disease for $dataset_id";
    $arrayexpress{$cellline} = [$mt_ftp_link."/".$mt_file];
  }
}

close(SDRF);
my %docs;
foreach my $cell_line (keys %arrayexpress){
  my $cgap_ips_line = List::Util::first {$_->name eq $cell_line} @$cgap_ips_lines;
  my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                  : List::Util::first {$_->name eq $cell_line} @$cgap_tissues;
  die 'did not recognise sample ->'.$cell_line.'<-' if !$cgap_tissue;
  my $source_material = $cgap_tissue->tissue_type || '';
  my $cell_type = $cgap_ips_line ? 'iPSC'
                : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                : die "did not recognise source material $source_material";
  my @files;
  my %zip_file;
  foreach my $file (@{$arrayexpress{$cell_line}}){
    my @fileparts = split("/", $file);
    my $filename = $fileparts[-1];
    push(@files, $filename);
    $zip_file{$filename} = $fileparts[-2];
  }
  my @dates;
  foreach my $file (@files) {
    push(@dates, $file =~ /\.(\d{8})\./);
  }
  my ($date) = sort {$a <=> $b} @dates;

  my $growing_conditions;
    if ($cgap_ips_line) {
      my $release_type = $short_assay eq 'mtarray' ? 'qc2' : 'qc1';
      my $cgap_release = $cgap_ips_line->get_release_for(type => $release_type, date =>$date);
      $growing_conditions = $cgap_release && $cgap_release->is_feeder_free ? 'Feeder-free'
                        : $cgap_release && !$cgap_release->is_feeder_free ? 'Feeder-dependent'
                        : $cell_line =~ /_\d\d$/ ? 'Feeder-free'
                        : $cgap_ips_line->passage_ips && $cgap_ips_line->passage_ips lt 20140000 ? 'Feeder-dependent'
                        : $cgap_ips_line->qc1 && $cgap_ips_line->qc1 lt 20140000 ? 'Feeder-dependent'
                        : die "could not get growing conditions for @files";
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
                        : $ext eq 'txt' && $short_assay eq 'gexarray' ? 'GenomeStudio text file'
                        : die "did not recognise type of $filename";

    $files{$ext}{$file_description}{$filename} = $files[0];
  }

  while (my ($ext, $date_hash) = each %files) {
    while (my ($file_description, $file_hash) = each %{$files{$ext}}) {
      my $es_id = join('-', $cell_line, $short_assay, lc($file_description), $ext);
      $es_id =~ s/\s/_/g;
      my @folderparts = split("-", $dataset_id);
      my $folderid = $folderparts[1];

      $docs{$es_id} = {
        description => $file_description,
        files => [
        ],
        archive => {
          name => 'ArrayExpress',
          url => 'http://www.ebi.ac.uk/arrayexpress/experiments/'.$dataset_id.'/',
          ftpUrl => 'ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/'.$folderid."/".$dataset_id.'/',
          openAccess => 1,
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
        }
      };
      while (my ($filename, $file_object) = each %$file_hash) {
        push(@{$docs{$es_id}{files}}, {name => $zip_file{$filename}."/".$filename, md5 => $file_object->md5, type => $ext});
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
            'archive.name' => 'ArrayExpress',
          },
        }
      }
    }
  }
));

my $date = strftime('%Y%m%d', localtime);
ES_DOC:
while (my $es_doc = $scroll->next) {
  next ES_DOC if $es_doc->{_source}{archive}{accessionType} && CORE::fc($es_doc->{_source}{archive}{accessionType}) eq CORE::fc('ANALYSIS_ID');
  next ES_DOC if $es_doc->{_source}{archive}{accessionType} && CORE::fc($es_doc->{_source}{archive}{accessionType}) eq CORE::fc('RUN_ID');
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
