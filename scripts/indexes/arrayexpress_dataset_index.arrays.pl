#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use LWP::Simple;
use Getopt::Long;

my $dataset_id;
my $outfolder = './';
my $demographic_filename;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
#NOTE: Don't use password with g1kro so leave undef
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';

GetOptions(
    'dataset_id=s'    => \$dataset_id,
    'outfolder=s'    => \$outfolder,
    'demographic_file=s'  => \$demographic_filename,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbport=s'      => \$dbport,
);

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor;

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my $assay;
my $filename_disease;
my $study_title;
my $platform;

my $sdrf = "http://www.ebi.ac.uk/arrayexpress/files/".$dataset_id."/".$dataset_id.".sdrf.txt";
my $idf = "http://www.ebi.ac.uk/arrayexpress/files/".$dataset_id."/".$dataset_id.".idf.txt";

my $idf_file = get $idf;
open( IDF, '<', \$idf_file );
while (my $line = <IDF>) {
  if ($line =~/^Investigation Title/){
    my @parts = split("\t", $line);
    $study_title = $parts[1];
    $assay = $study_title =~ /methylation/i ? 'mtarray'
          : $study_title =~ /HumanExome/i ? 'gtarray'
          : $study_title =~ /expression/i ? 'gexarray'
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
shift(@sdrflines);

my @filestoprocess;
if ($assay eq 'gexarray'){
  foreach my $line (@sdrflines) {
    my @parts = split("\t", $line);
    my $cellline = $parts[0];
    my $raw_ftp_link = $parts[33];
    my $raw_file = $parts[32];
    my $processed_ftp_link = $parts[36];
    my $processed_file = $parts[35];
    $processed_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;  
    $raw_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;
    $filename_disease = $parts[8];
    if ($filename_disease eq 'normal'){$filename_disease = 'healthy_volunteers';}
    $arrayexpress{$cellline} = [$raw_ftp_link."/".$raw_file, $processed_ftp_link."/".$processed_file];
  }
  my @rawoutput = [$outfolder.join('.', 'ArrayExpress', $dataset_id, $assay, $filename_disease, 'raw', 'array_files',  'tsv'), 0];
  my @processedoutput = [$outfolder.join('.', 'ArrayExpress', $dataset_id, $assay, $filename_disease, 'processed', 'array_files',  'tsv'), 1];
  push(@filestoprocess, @rawoutput);
  push(@filestoprocess, @processedoutput);
}elsif($assay eq 'mtarray'){
  foreach my $line (@sdrflines) {
    my @parts = split("\t", $line);
    my $cellline = $parts[0];
    my $mt_ftp_link = $parts[35];
    my $mt_file = $parts[34];
    $mt_ftp_link =~ s?ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/MTAB?http://www.ebi.ac.uk/arrayexpress/files?;
    $filename_disease = $parts[8];
    #Get specific methylation version
    $platform = $mt_file =~ /HumanMethylation450v1/i ? 'HumanMethylation450 v1'
          : die "did not recognise platform for $study_title in file $mt_file";
    if ($filename_disease eq 'normal'){$filename_disease = 'healthy_volunteers';}
    $arrayexpress{$cellline} = [$mt_ftp_link."/".$mt_file];
  }
    my @mtoutput = [$outfolder.join('.', 'ArrayExpress', $dataset_id, $assay, $filename_disease, 'array_files',  'tsv'), 0];
    push(@filestoprocess, @mtoutput);
}

close(SDRF);

for my $outputfile (@filestoprocess){
  open my $fh, '>', @$outputfile[0] or die "could not open $outputfile $!";
  print $fh "##ArrayExpress study title: $study_title\n";
  print $fh "##ArrayExpress dataset ID: $dataset_id\n";
  print $fh '##Assay: ', ($assay eq 'gtarray' ? 'Genotyping array' : $assay eq 'gexarray' ? 'Expression array' : $assay eq 'mtarray' ? 'Methylation array' : die "did not recognise assay $assay"), "\n";
  print $fh "##Disease cohort: $filename_disease\n";
  print $fh '#', join("\t", qw(
     file_url md5 cell_line biosample_id file_description platform file_date cell_type source_material sex growing_conditions
  )), "\n";

  row:
  foreach my $cell_line (keys %arrayexpress){
    my $file_url =  $arrayexpress{$cell_line}[@$outputfile[1]];
    my @fileparts = split("/", $file_url);
    my $filename = $fileparts[-1];
    my $cgap_ips_line = List::Util::first {$_->name eq $cell_line} @$cgap_ips_lines;
    my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                    : List::Util::first {$_->name eq $cell_line} @$cgap_tissues;
    die 'did not recognise sample ->'.$cell_line.'<-' if !$cgap_tissue;
    my $source_material = $cgap_tissue->tissue_type || '';
    my $cell_type = $cgap_ips_line ? 'iPSC'
                  : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                  : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                  : die "did not recognise source material $source_material";
    my ($ext) = $filename =~ /\.(\w+)(?:\.gz)?$/;
    my @files = grep {!$_->withdrawn && $_->name !~ m{/withdrawn/}} @{$fa->fetch_by_filename($filename)};
    
    if (!@files) {
      print "skipping $filename - did not recognise it\n";
    }
    die "multiple files for $filename" if @files>1;
    my $file_description = $ext eq 'vcf' && $filename =~ /imputed_phased/ ?  'imputed and phased genotypes'
                          : $ext eq 'vcf' ? 'genotype calls vcf format'
                          : $ext eq 'idat' ? 'array signal intensity data'
                          : $ext eq 'gtc' ? 'genotype calls gtc format'
                          : $ext eq 'txt' && $assay eq 'mtarray' ? 'text file with probe intensities'
                          : undef;
    if ($ext eq 'txt' && $assay eq 'gexarray' && $filename =~ m{\.\w+_profile\.}) {
      $file_description = 'array signal intensity signal data'
    }
    die "did not recognise type of $filename" if !$file_description;

    my $file_date = join('-', $filename =~ /\.(\d{4})(\d{2})(\d{2})\./);

    my $growing_conditions;
    if ($cgap_ips_line) {
      my $release_type = $assay eq 'mtarray' ? 'qc2' : 'qc1';
      my $cgap_release = $cgap_ips_line->get_release_for(type => $release_type, date =>$file_date);
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

    print $fh join("\t",
      $file_url, 
      $files[0]->md5,
      $cell_line,
      ($cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id),
      $file_description,
      $platform,
      $file_date,
      $cell_type,
      $source_material,
      $cgap_tissue->donor->gender || '',
      $growing_conditions || '',
    ), "\n";
  }
}
