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
my $file_type = 'CELLBIOL-FN_MISC';
my $trim = '/nfs/hipsci';
my $description = 'Images and figures';

&GetOptions(
    'es_host=s' => \$es_host,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
    'file_type=s'      => \$file_type,
    'trim=s'      => \$trim,
    'demographic_file=s' => \$demographic_filename,
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

my %cell_line_files;
FILE:
foreach my $file (@{$fa->fetch_by_type($file_type)}) {
  next FILE if $file->name !~ /pdf$/;
  next FILE if $file->name !~ /$trim/ || $file->name =~ m{/withdrawn/};
  my ($cell_line_name) = split(/\./, $file->filename);
  next FILE if $cell_line_name =~ m{zumy};
  next FILE if $cell_line_name =~ m{qifc};
  $cell_line_files{$cell_line_name} //= [];
  push(@{$cell_line_files{$cell_line_name}}, $file);
}

my %docs;
SAMPLE:
while (my ($cell_line, $files) = each %cell_line_files) {
  my $dir = dirname($files->[0]->name);
  $dir =~ s{$trim}{};

  my $cgap_ips_line = $cgap_ips_line_hash{$cell_line};
  my $cgap_tissue = $cgap_ips_line ? $cgap_ips_line->tissue
                  : $cgap_tissues_hash{$cell_line};
  die 'did not recognise sample '.$cell_line if !$cgap_tissue;

  my $source_material = $cgap_tissue->tissue_type || '';
  my $cell_type = $cgap_ips_line ? 'iPSC'
                : CORE::fc($source_material) eq CORE::fc('skin tissue') ? 'Fibroblast'
                : CORE::fc($source_material) eq CORE::fc('whole blood') ? 'PBMC'
                : die "did not recognise source material $source_material";

  my $growing_conditions;
  if ($cgap_ips_line) {
    my $cgap_release = $cgap_ips_line->get_release_for(type => 'qc2', date =>$files->[0]->created);
    $growing_conditions = $cgap_release && $cgap_release->is_feeder_free ? 'Feeder-free'
                      : $cgap_release && !$cgap_release->is_feeder_free ? 'Feeder-dependent'
                      : $cell_line =~ /_\d\d$/ ? 'Feeder-free'
                      : $cgap_ips_line->passage_ips && $cgap_ips_line->passage_ips lt 20140000 ? 'Feeder-dependent'
                      : die "could not get growing conditions for $cell_line";
  }
  else {
    $growing_conditions = $cell_type;
  }

  my $disease = $cgap_tissue->donor->disease;
  $disease = $disease eq 'normal' ? 'Normal'
          : $disease =~ /bardet-/ ? 'Bardet-Biedl'
          : $disease eq 'neonatal diabetes' ? 'Neonatal diabetes mellitus'
          : die "did not recognise disease $disease";



  my $es_id = join('-', $cell_line, 'cellbiol-fn', 'pdf');
  $es_id =~ s/\s/_/g;
  $docs{$es_id} = {
    description => $description,
    files => [
    ],
    archive => {
      name => 'HipSci FTP',
      url => "ftp://ftp.hipsci.ebi.ac.uk$dir",
      ftpUrl => "ftp://ftp.hipsci.ebi.ac.uk$dir",
      openAccess => 1,
    },
    samples => [{
      name => $cell_line,
      bioSamplesAccession => $cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id,
      cellType => $cell_type,
      diseaseStatus => $disease,
      sex => $cgap_tissue->donor->gender,
      growingConditions => $growing_conditions,
    }],
    assay => {
      type => 'Cellular phenotyping',
    }
  };

  FILE:
    foreach my $file (@$files) {
      push(@{$docs{$es_id}{files}}, 
          {
            name => $file->filename,
            md5 => $file->md5,
            type => 'pdf',
          }
        );
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
          term => {
            'assay.type' => 'Cellular phenotyping',
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

