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

my $es_host='ves-hx-e3:9200'; # eleasticserach
my $dbhost = 'mysql-g1kdcc-public';  # eleasticserach
my $demographic_filename; # not sure
my $dbuser = 'g1kro'; # eleasticserach
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_track';
my $trim = '/nfs/hipsci';
my $description = 'Varient Effect Predictor multiple cell lines';
my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';

#
my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
# print Dumper($elasticsearch);
# $VAR1 = bless( {
#                  'host' => 'ves-hx-e3:9200'
#                }, 'ReseqTrack::Tools::HipSci::ElasticsearchClient' );
my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
# print '#############################';
# print Dumper($db);
# $VAR1 = bless( {
#  '_dbc' => bless( {
#                     '_port' => 4197,
#                     '_host' => 'mysql-g1kdcc-public',
#                     '_driver' => 'mysql',
#                     '_dbname' => 'hipsci_track',
#                     '_username' => 'g1kro',
#                     '_timeout' => 0
#                   }, 'ReseqTrack::DBSQL::DBConnection' )
# }, 'ReseqTrack::DBSQL::DBAdaptor' );
# print '#############################';

my $fa = $db->get_FileAdaptor;
# print Dumper($fa);
# $VAR1 = bless( {
#    'db' => bless( {
#                     '_dbc' => bless( {
#                                        '_port' => 4197,
#                                        '_host' => 'mysql-g1kdcc-public',
#                                        '_driver' => 'mysql',
#                                        '_dbname' => 'hipsci_track',
#                                        '_username' => 'g1kro',
#                                        '_timeout' => 0
#                                      }, 'ReseqTrack::DBSQL::DBConnection' ),
#                     'ReseqTrack::DBSQL::FileAdaptor' => $VAR1
#                   }, 'ReseqTrack::DBSQL::DBAdaptor' ),
#    'dbc' => $VAR1->{'db'}{'_dbc'}
#  }, 'ReseqTrack::DBSQL::FileAdaptor' );
# print Dumper($db);

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
# the above uses read_cgap_report from  ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils module to get
#  some data.
# print Dumper($cgap_ips_lines);
# print '#############################';
# print Dumper($cgap_tissues);
# print '#############################';
# print Dumper($cgap_donors);
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename); # improve_donors method

my (%cgap_ips_line_hash, %cgap_tissues_hash);
# print Dumper(%cgap_ips_line_hash);    # uninitialized still.
foreach my $cell_line (@$cgap_ips_lines) {   # for each cellline in this array (dereferencing an array ref)
  $cgap_ips_line_hash{$cell_line->name} = $cell_line;
  $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue;
  # print Dumper($cgap_ips_line_hash); # returns an error.
  # last;
}
# so far we have defined two dictionaries, one $cgap_ips_line_hash and one  $cgap_tissues_hash.
# print Dumper(%cgap_ips_line_hash);
# $VAR6271 = 'HPSI0613i-oomz_3';
# $VAR6272 = $VAR1710->{'tissue'}{'ips_lines'}[2];
my $date = '20180831';
my $label = 'vep_openaccess_bcf';

my %file_sets;
foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {
  my $file_path = $file->name;
  next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
  $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
  push(@{$file_sets{$label}{files}}, $file);
}
print Dumper(@{$file_sets{$label}{files}});
# $VAR22 = bless( {
#                   'withdrawn' => '0',
#                   'adaptor' => $VAR1->{'adaptor'},
#                   'host_id' => '1',
#                   'name' => '/nfs/hipsci/vol1/ftp/data/vep_openaccess_bcf/chr2.bcf',
#                   'size' => '757225864',
#                   'created' => '2018-09-06 12:36:25',
#                   'dbID' => '59597',
#                   'updated' => '2018-09-06 13:14:44',
#                   'type' => 'MISC',
#                   'md5' => 'ab15228dff995b2d3fadc2096c9b55be'
#                 }, 'ReseqTrack::File' );
# $VAR23 = bless( {
#                   'withdrawn' => '0',
#                   'adaptor' => $VAR1->{'adaptor'},
#                   'host_id' => '1',
#                   'name' => '/nfs/hipsci/vol1/ftp/data/vep_openaccess_bcf/chr17.bcf',
#                   'size' => '265755167',
#                   'created' => '2018-09-06 12:36:21',
#                   'dbID' => '59596',
#                   'updated' => '2018-09-06 13:14:45',
#                   'type' => 'MISC',
#                   'md5' => '156c1fcfd2b83ef6c76fd5b7980eb549'
#                 }, 'ReseqTrack::File' );
# #####
open my $fh, '<', $sample_list or die "could not open $sample_list $!";  # opens a file.
my @open_access_samples;
my @lines = <$fh>;
foreach my $line (@lines){
  chomp($line);
  push(@open_access_samples, $line)
}

# SO fra we built below:
#    1 %cgap_ips_line_hash
#    2 %cgap_tissues_hash
#    3 $file_sets
#    4 @open_access_samples
# I think so far was just preparing data.


#############################
my %docs;
FILE:
# my $i = 0;
foreach my $file_set (values %file_sets) {
  # print Dumper($file_set);
  # print $i;
  # $i = $i +1;
  # last;
  # }
  my $dir = $file_set->{dir}; # defined $dir, used defined var no 3.
  $dir =~ s{$trim}{};
  my @samples;
  CELL_LINE:
  foreach my $cell_line (@open_access_samples) { # used defined var no 4
    # print $cell_line; # HPSI1213i-pahc_5, etc
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
    # print $content;
    # {"_index":"hipsci_20190313_070003","_type":"file","_id":"HPSI0114i-bezi_1-rnaseq-ERZ267062","_score":1.0,"_source":{"samples":[{"cellType":"iPSC","growingConditions":"Feeder-free","diseaseStatus":"Normal","bioSamplesAccession":"SAMEA2518325","name":"HPSI0114i-bezi_1","sex":"female","passageNumber":"29"}],"assay":{"instrument":"Illumina HiSeq 2000","type":"RNA-seq","description":["INSTRUMENT_PLATFORM=ILLUMINA","INSTRUMENT_MODEL=Illumina HiSeq 2000","LIBRARY_LAYOUT=PAIRED","LIBRARY_STRATEGY=RNA-Seq","LIBRARY_SOURCE=TRANSCRIPTOMIC","LIBRARY_SELECTION=cDNA","PAIRED_NOMINAL_LENGTH=550"]},"archive":{"accessionType":"ANALYSIS_ID","openAccess":1,"ftpUrl":"ftp://ftp.sra.ebi.ac.uk/vol1/ERZ267/ERZ267062/","url":"http://www.ebi.ac.uk/ena/data/view/ERZ267062","name":"ENA","accession":"ERZ267062"},"_indexUpdated":"20181129","files":[{"name":"HPSI0114i-bezi_1.GRCh37.75.cdna.kallisto.transcripts.abundance.rnaseq.20150415.tsv","type":"other","md5":"7bf7dee6e08b61b899809fa063d83a82"}],"_indexCreated":"20181129","description":"Abundances of transcripts"}}
    my $json = new JSON;
    my $json_text = $json->decode($content);
    print $json_text;
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
############################
#
# # # No need to change this part.
# # my $scroll = $elasticsearch->call('scroll_helper', (
# #   index => 'hipsci',
# #   type => 'file',
# #   search_type => 'scan',
# #   size => 500,
# #   body => {
# #     query => {
# #       filtered => {
# #         filter => {
# #           term => {
# #             description => $description
# #           },
# #         }
# #       }
# #     }
# #   }
# # ));
# #
# # my $systemdate = strftime('%Y%m%d', localtime);
# # ES_DOC:
# # while (my $es_doc = $scroll->next) {
# #   my $new_doc = $docs{$es_doc->{_id}};
# #   if (!$new_doc) {
# #     printf("curl -XDELETE http://%s/%s/%s/%s\n", $es_host, @$es_doc{qw(_index _type _id)});
# #     next ES_DOC;
# #   }
# #   delete $docs{$es_doc->{_id}};
# #   my ($created, $updated) = @{$es_doc->{_source}}{qw(_indexCreated _indexUpdated)};
# #   $new_doc->{_indexCreated} = $es_doc->{_source}{_indexCreated} || $systemdate;
# #   $new_doc->{_indexUpdated} = $es_doc->{_source}{_indexUpdated} || $systemdate;
# #   next ES_DOC if Compare($new_doc, $es_doc->{_source});
# #   $new_doc->{_indexUpdated} = $systemdate;
# #   $elasticsearch->index_file(id => $es_doc->{_id}, body => $new_doc);
# # }
# # while (my ($es_id, $new_doc) = each %docs) {
# #   $new_doc->{_indexCreated} = $systemdate;
# #   $new_doc->{_indexUpdated} = $systemdate;
# #   $elasticsearch->index_file(body => $new_doc, id => $es_id);
# # }