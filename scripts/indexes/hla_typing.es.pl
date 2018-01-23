#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Search::Elasticsearch;
use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use File::Basename qw(dirname);
use Data::Compare;
use POSIX qw(strftime);

my $es_host='ves-hx-e3:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $demographic_filename;
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $trim = '/nfs/hipsci';
my $description = 'HLA typing multiple cell lines';
my $file_pattern = 'gtarray/hla_typing/%/hipsci.wec.gtarray.%';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/tracked';

my %filetype_of = (bed => 'plink', bgl => 'beagle', bim => 'plink', fam => 'plink', dosage => 'beagle', nosex => 'beagle');

&GetOptions(
    'es_host=s' => \$es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'trim=s'      => \$trim,
    'demographic_file=s' => \$demographic_filename,
    'file_pattern=s'      => \$file_pattern,
);

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

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
my (%cgap_ips_line_hash, %cgap_tissues_hash);
foreach my $cell_line (@$cgap_ips_lines) {
  $cgap_ips_line_hash{$cell_line->name} = $cell_line;
  $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue;
}

my %file_sets;
foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {
  my $file_path = $file->name;
  next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
  my ($label, $date) = $file->name =~ /\.([^\.]*)\.(\d{8})\./;
  die "did not get date from file ".$file->filename if !$date;
  $label .= "-$date";
  $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
  push(@{$file_sets{$label}{files}}, $file);
}

my %docs;
FILE:
foreach my $file_set (values %file_sets) {
  my $dir = $file_set->{dir};
  $dir =~ s{$trim}{};

  my ($fam_file) = grep {$_->filename =~ /\.fam$/} @{$file_set->{files}};
  die 'did not get fam file for '.$file_set->{label} if !$fam_file;
  my $fam_path = $fam_file->name;
  $fam_path =~ s{^$drop_trim}{$drop_base};

  my @samples;
  open my $fh, '<', $fam_path or die "could not open $fam_path: $!";
  CELL_LINE:
  while (my $line = <$fh>) {
    chomp $line;
    my ($cell_line) = split(/\s+/, $line);
    next CELL_LINE if !$cell_line;

    my $cgap_ips_line = $cgap_ips_line_hash{$cell_line};
    my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                    : $cgap_tissues_hash{$cell_line};
    die 'did not recognise sample '.$cell_line if !$cgap_tissue;

    my $source_material = $cgap_tissue->tissue_type || '';
    my $cell_type = $cgap_ips_line ? 'iPSC'
                  : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                  : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                  : die "did not recognise source material $source_material";

    my $disease = $cgap_tissue->donor->disease;
    $disease = $disease eq 'normal' ? 'Normal'
            : $disease =~ /bardet-/ ? 'Bardet-Biedl'
            : $disease eq 'neonatal diabetes' ? 'Monogenic diabetes'
            : die "did not recognise disease $disease";

    my %sample = (
        name => $cell_line,
        bioSamplesAccession => $cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id,
        cellType => $cell_type,
        diseaseStatus => $disease,
        sex => $cgap_tissue->donor->gender,
    );

    if ($cgap_ips_line) {
      my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc1', date =>$file_set->{date});
      $sample{growingConditions} = $cgap_release && $cgap_release->is_feeder_free ? 'Feeder-free'
                        : $cgap_release && !$cgap_release->is_feeder_free ? 'Feeder-dependent'
                        : $cell_line =~ /_\d\d$/ ? 'Feeder-free'
                        : $cgap_ips_line->passage_ips && $cgap_ips_line->passage_ips lt 20140000 ? 'Feeder-dependent'
                        : $cgap_ips_line->qc1 && $cgap_ips_line->qc1 lt 20140000 ? 'Feeder-dependent'
                        : die "could not get growing conditions for $cell_line";
      if ($cgap_release && $cgap_release->passage) {
        $sample{passageNumber} = $cgap_release->passage;
      }

    }
    else {
      $sample{growingConditions} = $cell_type;
    }
    
    push(@samples, \%sample);
  }

  my ($basename) = $fam_file->filename =~ /^(.*)\.fam$/;

  my @files;
  foreach my $file (@{$file_set->{files}}) {
    my ($ext) = $file->filename =~ /^$basename\.(.*)$/;
    $ext =~ s/\..*//;
    my $filetype = $filetype_of{$ext};
    die "no file type for $ext" if !$filetype;
    push(@files, {
      name => $file->filename,
      md5 => $file->md5,
      type => $filetype,
    });
  }


  my $es_id = join('-', $file_set->{label}, 'hla-typing');
  $es_id =~ s/\s/_/g;
  $docs{$es_id} = {
    description => $description,
    files => \@files,
    archive => {
      name => 'HipSci FTP',
      url => "ftp://ftp.hipsci.ebi.ac.uk$dir",
      ftpUrl => "ftp://ftp.hipsci.ebi.ac.uk$dir",
      openAccess => 1,
    },
    samples => \@samples,
    assay => {
      type => 'Genotyping array',
      description => ['SOFTWARE=SNP2HLA', 'PLATFORM=Illumina beadchip HumanCoreExome-12'],
      instrument => 'Illumina beadchip HumanCoreExome-12',
    }
  };
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
          term => {
            description => $description
          },
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

