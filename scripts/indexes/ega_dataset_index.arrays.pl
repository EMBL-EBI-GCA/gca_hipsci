#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch);
use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(fileparse);
use XML::Simple qw(XMLin);
use Getopt::Long;

# my @era_params = ('ops$laura', undef, 'ERAPRO');
# my $demographic_filename;
# my %dataset_files;
# my $dbhost = 'mysql-g1kdcc-public';
# my $dbuser = 'g1kro';
# my $dbpass;
# my $dbport = 4197;
# my $dbname = 'hipsci_private_track';

# GetOptions(
    # 'era_password=s'    => \$era_params[1],
    # 'dataset=s'    => \%dataset_files,
    # 'demographic_file=s' => \$demographic_filename,
    # 'dbhost=s'      => \$dbhost,
    # 'dbname=s'      => \$dbname,
    # 'dbuser=s'      => \$dbuser,
    # 'dbpass=s'      => \$dbpass,
    # 'dbport=s'      => \$dbport,
# );

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

my $era_db = get_erapro_conn(@era_params);
$era_db->dbc->db_handle->{LongReadLen} = 4000000;

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my $sql_study =  'select xmltype.getclobval(study_xml) study_xml from study where ega_id=?';
my $sth_study = $era_db->dbc->prepare($sql_study) or die "could not prepare $sql_study";

while (my ($dataset_id, $submission_file) = each %dataset_files) {
  my $filename = fileparse($submission_file);
  my ($study_id) = $filename =~ /(EGAS\d+)/;
  die "did not recognise study_id from $submission_file" if !$study_id;

  $sth_study->bind_param(1, $study_id);
  $sth_study->execute or die "could not execute";
  my $row = $sth_study->fetchrow_hashref;
  die "no study $study_id" if !$row;
  my $xml_hash = XMLin($row->{STUDY_XML});

  my $assay = $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /expression/i ? 'gexarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /HumanExome/i ? 'gtarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE} =~ /methylation/i ? 'mtarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /expression/i ? 'gexarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /HumanExome/i ? 'gtarray'
            : $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION} =~ /methylation/i ? 'mtarray'
            : die "did not recognise assay for $study_id";
  my $disease = get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}) || get_disease_for_elasticsearch($xml_hash->{STUDY}{DESCRIPTOR}{STUDY_DESCRIPTION});
  die "did not recognise disease for $study_id" if !$disease;
  my $filename_disease = lc($disease);
  $filename_disease =~ s{[ -]}{_}g;

  open my $in_fh, '<', $submission_file or die "could not open $submission_file $!";
  <$in_fh>;

  my $output = join('.', 'EGA', $dataset_id, $assay, $filename_disease, 'tsv');
  open my $fh, '>', $output or die "could not open $output $!";
  print $fh '##EGA study title: ', $xml_hash->{STUDY}{DESCRIPTOR}{STUDY_TITLE}, "\n";
  print $fh "##EGA dataset ID: $dataset_id\n";
  print $fh '##Assay: ', ($assay eq 'gtarray' ? 'Genotyping array' : $assay eq 'gexarray' ? 'Expression array' : $assay eq 'mtarray' ? 'Methylation array' : die "did not recognise assay $assay"), "\n";
  print $fh "##Disease cohort: $disease\n";
  print $fh '#', join("\t", qw(
    filename md5 cell_line biosample_id file_description platform file_date cell_type source_material sex growing_conditions
  )), "\n";


  ROW:
  while (my $line = <$in_fh>) {
    my ($cell_line, $platform, $raw_file, undef, $signal_file, undef, $software, $genotype_file) = split("\t", $line);
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

    my @files = map {split(';', $_)} grep {$_} ($raw_file, $signal_file, $genotype_file);
    my @dates;
    foreach my $file (@files) {
      push(@dates, $file =~ /\.(\d{8})\./);
    }
    my ($date) = sort {$a <=> $b} @dates;

    my $growing_conditions;
    if ($cgap_ips_line) {
      my $release_type = $assay eq 'mtarray' ? 'qc2' : 'qc1';
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
      #die "no files for $filename" if !@files;
      die "multiple files for $filename" if @files>1;

      my $file_description = $ext eq 'vcf' && $filename =~ /imputed_phased/ ?  'imputed and phased genotypes'
                          : $ext eq 'vcf' ? 'genotype calls vcf format'
                          : $ext eq 'idat' ? 'array signal intensity data'
                          : $ext eq 'gtc' ? 'genotype calls gtc format'
                          : $ext eq 'txt' && $assay eq 'mtarray' ? 'text file with probe intensities'
                          : undef;
      if ($ext eq 'txt' && $assay eq 'gexarray' && $filename =~ m{\.(\w+_profile)\.}) {
        $file_description = $1;
        $file_description =~ s/_/ /;
      }
      die "did not recognise type of $filename" if !$file_description;

      my $file_date = join('-', $filename =~ /\.(\d{4})(\d{2})(\d{2})\./);

      print $fh join("\t",
        $filename, $files[0]->md5,
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

  close $fh;
}
