# Need to run this code for each IDR separately. IDR data is saved in '/homes/hipdcc/IDR_data/IDR_data'
# The python code to collect the data is also saved there.
# $filename (json file containing IDR data) and  $IDR_No (name/number of the specific IDR)
# Ex: '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_1901.json' and 'idr0034-kilpinen-hipsci/screenA'

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
my $demographic_filename;
my $description = 'High content fluorescence microscopy';

# below two variables need to be updated accordingly based on each specific IDR:
my $filename = '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_2051.json';  # IDR json data file
my $IDR_No = 'idr0037-vigilante-hipsci/screenA'; # IDR file name

# for IDR0034: '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_1901.json' and 'idr0034-kilpinen-hipsci/screenA';
# my $filename = '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_1901.json';  # IDR json data file
# my $IDR_No = 'idr0034-kilpinen-hipsci/screenA'; # IDR file name

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);
my (%cgap_ips_line_hash, %cgap_tissues_hash);
foreach my $cell_line (@$cgap_ips_lines) {
  $cgap_ips_line_hash{$cell_line->name} = $cell_line;
  $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue;
}
my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $json = JSON->new;
my $data = $json->decode($json_text);
my @experiment_array = keys %$data;

my %docs;
FILE:
foreach my $exp (@experiment_array) {
    my $es_id = join('-', $IDR_No, $exp);
    $es_id =~ s/\s/_/g;
    $docs{$es_id} = {
        description => $description,
        files => [{
            name => $IDR_No . '-' . $exp,
        }],
        archive     => {
            name       => 'IDR',
            url        => $data->{$exp}{'File download'},
            ftpUrl     => $data->{$exp}{'File download'},
            accession => $exp,
            openAccess => 1,
        },
        samples => [{
            name => $data->{$exp}{'Cell line'},
            bioSamplesAccession => $exp,
            sex => $data->{$exp}{'Sex'},
        }],
        assay       => {
            type        => 'High content imaging',
            description => [ 'SOFTWARE=SNP2HLA', 'PLATFORM=Illumina beadchip HumanCoreExome-12' ],
            instrument  => 'Operetta',
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