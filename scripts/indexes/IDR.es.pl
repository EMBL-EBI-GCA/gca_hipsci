
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
my $trim = '/nfs/hipsci';
my $description = 'Image Data Resource';
my $filename = '/homes/hipdcc/IDR_data/IDR_json_data.json';  # IDR json data file
###  uncomment them:
# my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
#
# my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
# improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);
# my (%cgap_ips_line_hash, %cgap_tissues_hash);
# foreach my $cell_line (@$cgap_ips_lines) {
#   $cgap_ips_line_hash{$cell_line->name} = $cell_line;
#   $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue; # gets the data and builds both as required.
# }
# my $date = '20190326';
# my $label = 'IDR';
###
my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $json = JSON->new;
my $data = $json->decode($json_text);
# print Dumper($data);

print Dumper($data->{'experiment_31'});


# my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
# my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
# my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
# my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';


######### --> The part to search elasticsearch based on description (this needs to be IDR) and update the elasticsearch:
# my $scroll = $elasticsearch->call('scroll_helper', (
#   index => 'hipsci',
#   type => 'file',
#   search_type => 'scan',
#   size => 500,
#   body => {
#     query => {
#       filtered => {
#         filter => {
#           term => {
#             description => $description
#           },
#         }
#       }
#     }
#   }
# ));
#
# my $systemdate = strftime('%Y%m%d', localtime);
# ES_DOC:
# while (my $es_doc = $scroll->next) {
#   my $new_doc = $docs{$es_doc->{_id}};
#   if (!$new_doc) {
#     printf("curl -XDELETE http://%s/%s/%s/%s\n", $es_host, @$es_doc{qw(_index _type _id)});
#     next ES_DOC;
#   }
#   delete $docs{$es_doc->{_id}};
#   my ($created, $updated) = @{$es_doc->{_source}}{qw(_indexCreated _indexUpdated)};
#   $new_doc->{_indexCreated} = $es_doc->{_source}{_indexCreated} || $systemdate;
#   $new_doc->{_indexUpdated} = $es_doc->{_source}{_indexUpdated} || $systemdate;
#   next ES_DOC if Compare($new_doc, $es_doc->{_source});
#   $new_doc->{_indexUpdated} = $systemdate;
#   $elasticsearch->index_file(id => $es_doc->{_id}, body => $new_doc);
# }
# while (my ($es_id, $new_doc) = each %docs) {
#   $new_doc->{_indexCreated} = $systemdate;
#   $new_doc->{_indexUpdated} = $systemdate;
#   $elasticsearch->index_file(body => $new_doc, id => $es_id);
# }
######## <-- The end ########


################## How to get the json data ##################
# use warnings;
# use strict;
# use JSON::MaybeXS;
#
# # IDR data is saved in a json format in
# use Data::Dumper;
# use lib qw(..);
# use JSON qw( );
# my $filename = '/homes/hipdcc/IDR_data/IDR_json_data.json';
# my $json_text = do {
#    open(my $json_fh, "<:encoding(UTF-8)", $filename)
#       or die("Can't open \$filename\": $!\n");
#    local $/;
#    <$json_fh>
# };
# my $json = JSON->new;
# my $data = $json->decode($json_text);
# print Dumper($data);

# 'experiment_20' => {
#                    'Cell line' => [
#                                     'HPSI0513i-cuau_2'
#                                   ],
#                    'Instrument' => 'Operetta',
#                    'Sex' => [
#                               'female'
#                             ],
#                    'Assay' => 'High content imaging',
#                    'Archive' => undef,
#                    'Description' => 'High content fluorescence microscopy',
#                    'File download' => 'https://idr.openmicroscopy.org/webclient/?show=plate-6114',
#                    'Accession' => 'experiment_20'
#                  }
######## <-- The end ########
