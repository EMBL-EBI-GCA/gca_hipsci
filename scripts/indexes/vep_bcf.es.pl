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
use WWW::Mechanize;
use JSON -support_by_pp;
use Data::Dumper;

my $es_host='ves-hx-e3:9200';
my $dbhost = 'mysql-g1kdcc-public';
my $demographic_filename;
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $trim = '/nfs/hipsci';
my $description = 'Varient Effect Predictor multiple cell lines';
my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';


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

my $date = '20180831';
my $label = 'vep_openaccess_bcf';

my %file_sets;
foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {
  my $file_path = $file->name;
  next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
  $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
  push(@{$file_sets{$label}{files}}, $file);
}

open my $fh, '<', $sample_list or die "could not open $sample_list $!";
my @open_access_samples;
my @lines = <$fh>;
foreach my $line (@lines){
  chomp($line);
  push(@open_access_samples, $line)
}

my %docs;
FILE:
foreach my $file_set (values %file_sets) {
  my $dir = $file_set->{dir};
  $dir =~ s{$trim}{};
  my @samples;
  CELL_LINE:
  foreach my $cell_line (@open_access_samples){
    print $cell_line;
    my $browser = WWW::Mechanize->new();
    my $hipsci_api = 'http://www.hipsci.org/lines/api/file/_search';
    my $query =
    '{
      "size": 1000,
      "query": {
        "filtered": {
          "filter": {
            "term": {"samples.name": "'.$cell_line.'"}
          }
        }
      }
    }';
    $browser->post( $hipsci_api, content => $query );
    my $content = $browser->content();
    my $json = new JSON;
    my $json_text = $json->decode($content);
    foreach my $record (@{$json_text->{hits}{hits}}){
      if ($record->{_source}{assay}{type} eq 'Genotyping array' && $record->{_source}{description} eq 'Imputed and phased genotypes'){
        my %sample = (
          name => $cell_line,
          bioSamplesAccession => $record->{_source}{samples}[0]{bioSamplesAccession},
          cellType => $record->{_source}{samples}[0]{cellType},
          diseaseStatus => $record->{_source}{samples}[0]{diseaseStatus},
          sex => $record->{_source}{samples}[0]{sex},
          growingConditions => $record->{_source}{samples}[0]{growingConditions},
          passageNumber => $record->{_source}{samples}[0]{passageNumber},
        );
        push(@samples, \%sample);
      }
    }
  }

  my @files;
  foreach my $file (@{$file_set->{files}}) {
    my $filetype = 'vep_bcf';
    push(@files, {
      name => $file->filename,
      md5 => $file->md5,
      type => $filetype,
    });
  }

  my $es_id = join('-', $file_set->{label}, 'vep_openaccess_bcf');
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
            description => $description
          },
        }
      }
    }
  }
));

my $systemdate = strftime('%Y%m%d', localtime);
ES_DOC:
while (my $es_doc = $scroll->next) {
  my $new_doc = $docs{$es_doc->{_id}};
  if (!$new_doc) {
    printf("curl -XDELETE http://%s/%s/%s/%s\n", $es_host, @$es_doc{qw(_index _type _id)});
    next ES_DOC;
  }
  delete $docs{$es_doc->{_id}};
  my ($created, $updated) = @{$es_doc->{_source}}{qw(_indexCreated _indexUpdated)};
  $new_doc->{_indexCreated} = $es_doc->{_source}{_indexCreated} || $systemdate;
  $new_doc->{_indexUpdated} = $es_doc->{_source}{_indexUpdated} || $systemdate;
  next ES_DOC if Compare($new_doc, $es_doc->{_source});
  $new_doc->{_indexUpdated} = $systemdate;
  $elasticsearch->index_file(id => $es_doc->{_id}, body => $new_doc);
}
while (my ($es_id, $new_doc) = each %docs) {
  $new_doc->{_indexCreated} = $systemdate;
  $new_doc->{_indexUpdated} = $systemdate;
  $elasticsearch->index_file(body => $new_doc, id => $es_id);
}
