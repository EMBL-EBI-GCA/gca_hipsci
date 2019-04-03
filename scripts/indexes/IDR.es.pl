# Very importnt: Need to run this code for each IDR and give the IDR name like 'idr0034-kilpinen-hipsci/screenA' to a variable (IDR_NO)

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
my $description = 'High content fluorescence microscopy';
my $filename = '/homes/hipdcc/IDR_data/IDR_data/IDR_Screen_ID_1901.json';  # IDR json data file
##  uncomment them:
my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);
my (%cgap_ips_line_hash, %cgap_tissues_hash);
foreach my $cell_line (@$cgap_ips_lines) {
  $cgap_ips_line_hash{$cell_line->name} = $cell_line;
  $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue; # gets the data and builds both as required.
}
##


my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $json = JSON->new;
my $data = $json->decode($json_text); # hash reference, IDR json data
# print Dumper($data);
my @IDR_celllines; # cellline for the particular IDR like idr0034
my @experiment_array = keys %$data;
foreach my $experiment (@experiment_array) {
   foreach my $celllines ($data->{$experiment}{'Cell line'}) {
      foreach my $cellline (@$celllines) {
         push(@IDR_celllines, $cellline)
      }
   }
}

# foreach my $celllines ($data->{$exp}{'Cell line'}) {
#     # print Dumper ($celllines);
#     foreach my $cell_line (@$celllines) {
#         # print $cell_line;
# foreach my $cell_line (@IDR_celllines) {
#     my $browser = WWW::Mechanize->new();
#     my $hipsci_api = 'http://www.hipsci.org/lines/api/cellLine/_search';
#     my $query =
#     '{
#       "size": 1,
#       "query": {
#         "filtered": {
#           "filter": {
#             "term": {"name": "'.$cell_line.'"}
#           }
#         }
#       }
#     }';
#     $browser->post( $hipsci_api, content => $query );
#     my $content = $browser->content();
#     my $json = new JSON;
#     my $json_text = $json->decode($content);
#     my @record = @{$json_text->{hits}{hits}};
#     my $cellline_data = $record[0];
#     print($cellline_data -> {_source}{cellType}{value});
#     # print Dumper ($json_text);
    # last;


    # print Dumper(@test);
    # print Dumper($test[0]);
    # my $record (@{$json_text->{hits}{hits}})
    # print $json_text->{hits}{hits};#[0]{_source}{cellType}{value};

    # print Dumper($new_test['_source']);
    # print Dumper($new_test->{_source}{assay}{type});
    # last;
    # foreach my $record (@{$json_text->{hits}{hits}}) {
    #     print Dumper($cell_line);
    #     # print Dumper($record->{_source}{assay}{type});
    #     print Dumper($record->{_source}{cellType}{value});
    #     'Raw sequencing reads'
    # }
# }
# print Dumper(@IDR_celllines);
#### this is the only bit we haven't prepared:
# my %file_sets;
# foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {
#   my $file_path = $file->name;
#   next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
#   $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
#   push(@{$file_sets{$label}{files}}, $file);
# }
####

my $date = '20190326';
my $label = 'IDR';
my $IDR_No = 'idr0034-kilpinen-hipsci/screenA';

my %docs;
FILE:
foreach my $exp (@experiment_array) {
    # print Dumper($exp);
    my $es_id = join('-', $IDR_No, $exp);
    $es_id =~ s/\s/_/g;
    my %celltype_hash;
    foreach my $cell_line ($data->{$exp}{'Cell line'}) {
        print Dumper($cell_line);
        # my $browser = WWW::Mechanize->new();
        # my $hipsci_api = 'http://www.hipsci.org/lines/api/cellLine/_search';
        # my $query =
        # '{
        #   "size": 1,
        #   "query": {
        #     "filtered": {
        #       "filter": {
        #         "term": {"name": "'.$cell_line.'"}
        #       }
        #     }
        #   }
        # }';
        # $browser->post( $hipsci_api, content => $query );
        # my $content = $browser->content();
        # my $json = new JSON;
        # my $json_text = $json->decode($content);
        # my @record = @{$json_text->{hits}{hits}};
        # my $cellline_data = $record[0];
        # my %celltype_hash{} = 100;
        # print($cellline_data -> {_source}{cellType}{value});
    }
    # #     # print Dumper ($celllines);
    #     foreach my $cell_line (@$celllines) {
    #         my $browser = WWW::Mechanize->new();
    #         my $hipsci_api = 'http://www.hipsci.org/lines/api/cellLine/_search';
    #         my $query =
    #         '{
    #           "size": 1,
    #           "query": {
    #             "filtered": {
    #               "filter": {
    #                 "term": {"name": "'.$cell_line.'"}
    #               }
    #             }
    #           }
    #         }';
    #         $browser->post( $hipsci_api, content => $query );
    #         my $content = $browser->content();
    #         my $json = new JSON;
    #         my $json_text = $json->decode($content);
    #         # print Dumper ($json_text);
    #         # last;
    #         foreach my $record (@{$json_text->{hits}{hits}}) {
    #             print Dumper($cell_line);
    #             # print Dumper($record->{_source}{assay}{type});
    #             print Dumper($record->{_source}{cellType}{value});
    #             'Raw sequencing reads'
    #         }
    #     }
    #         print $cell_line;
    # #     #     my $browser = WWW::Mechanize->new();
    # #     #     my $hipsci_api = 'http://www.hipsci.org/lines/api/file/_search';
    # #     #     my $query =
    # #     #     '{
    # #     #       "size": 1000,
    # #     #       "query": {
    # #     #         "filtered": {
    # #     #           "filter": {
    # #     #             "term": {"samples.name": "'.$cell_line.'"}
    # #     #           }
    # #     #         }
    # #     #       }
    # #     #     }';
    # #     #     $browser->post( $hipsci_api, content => $query );
    # #     #     my $content = $browser->content();
    # #     #     my $json = new JSON;
    # #     #     my $json_text = $json->decode($content);
    # #     #     foreach my $record (@{$json_text->{hits}{hits}}) {
    # #     #         print Dumper($cell_line);
    # #     #         print Dumper($record->{_source}{samples}[0]{cellType});
    # #     #     }
    # #     }
    # }
    $docs{$es_id} = {
        description => $description,
        cellType => ,
        files => [{
            name => $exp,
            # md5 => $search_file->{md5},
            # type => $search_type,
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
            # cellType => $cell_type,
            sex => $data->{$exp}{'Sex'},
        }],
        # samples     => \@samples,
        assay       => {
            type        => 'High content imaging',
            description => [ 'SOFTWARE=SNP2HLA', 'PLATFORM=Illumina beadchip HumanCoreExome-12' ],
            instrument  => 'Operetta',
        }
    }
    # print Dumper($docs{$es_id});
}
# # foreach my $file_set (values %file_sets) {
# #                                 # ???
# #     my $dir = $file_set->{dir}; # ???
# #     $dir =~ s{$trim}{};         # ???
# #     my @samples;                # ???
# #     CELL_LINE:
# #     foreach my $cell_line (@IDR_celllines) {
# #         my $browser = WWW::Mechanize->new();
# #         my $hipsci_api = 'http://www.hipsci.org/lines/api/file/_search';
# #         my $query =
# #             '{
# #       "size": 1000,
# #       "query": {
# #         "filtered": {
# #           "filter": {
# #             "term": {"samples.name": "' . $cell_line . '"}
# #           }
# #         }
# #       }
# #     }';
# #         $browser->post($hipsci_api, content => $query);
# #         my $content = $browser->content();
# #         my $json = new JSON;
# #         my $json_text = $json->decode($content);
# #         # print Dumper($json_text);
# #         foreach my $record (@{$json_text->{hits}{hits}}) {
# #             # below if probably needs to be removed
# #             # if ($record->{_source}{assay}{type} eq 'Genotyping array' && $record->{_source}{description} eq 'Imputed and phased genotypes'){
# #             my %sample = (
# #                 name                => $cell_line,
# #                 bioSamplesAccession => $record->{_source}{samples}[0]{bioSamplesAccession},
# #                 cellType            => $record->{_source}{samples}[0]{cellType},
# #                 diseaseStatus       => $record->{_source}{samples}[0]{diseaseStatus},
# #                 sex                 => $record->{_source}{samples}[0]{sex},
# #                 growingConditions   => $record->{_source}{samples}[0]{growingConditions},
# #                 passageNumber       => $record->{_source}{samples}[0]{passageNumber},
# #             );
# #             push(@samples, \%sample);
# #             # }
# #         }
# #     }
#
#     # my @files;
#     # foreach my $file (@{$file_set->{files}}) { # ???
#     #   my $filetype = 'vep_bcf'; # ???
#     #   push(@files, {
#     #     name => $file->filename, # ???
#     #     md5 => $file->md5, # ???
#     #     type => $filetype, # ???
#     #   });
#     # }
#
#
#
# #   my $es_id = join('-', $file_set->{label}, 'vep_openaccess_bcf');
# #   $es_id =~ s/\s/_/g;
# #   print $es_id;
# #   $docs{$es_id} = {
# #     description => $description,
# #     files => \@files,
# #     archive => {
# #       name => 'HipSci FTP',
# #       url => "ftp://ftp.hipsci.ebi.ac.uk$dir",
# #       ftpUrl => "ftp://ftp.hipsci.ebi.ac.uk$dir",
# #       openAccess => 1,
# #     },
# #     samples => \@samples,
# #     assay => {
# #       type => 'Genotyping array',
# #       description => ['SOFTWARE=SNP2HLA', 'PLATFORM=Illumina beadchip HumanCoreExome-12'],
# #       instrument => 'Illumina beadchip HumanCoreExome-12',
# #     }
# #   }
# # }
#
#
#
# # my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
# # my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
# # my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
# # my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';
#
#
# ######### --> The part to search elasticsearch based on description (this needs to be IDR) and update the elasticsearch:
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
#   if (!$new_doc) {filename
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
# ######## <-- The end ########
#
#
# ################## How to get the json data ##################
# # use warnings;
# # use strict;
# # use JSON::MaybeXS;
# #
# # # IDR data is saved in a json format in
# # use Data::Dumper;
# # use lib qw(..);
# # use JSON qw( );
# # my $filename = '/homes/hipdcc/IDR_data/IDR_json_data.json';
# # my $json_text = do {
# #    open(my $json_fh, "<:encoding(UTF-8)", $filename)
# #       or die("Can't open \$filename\": $!\n");
# #    local $/;
# #    <$json_fh>
# # };
# # my $json = JSON->new;
# # my $data = $json->decode($json_text);
# # print Dumper($data);
#
# # 'experiment_20' => {
# #                    'Cell line' => [
# #                                     'HPSI0513i-cuau_2'
# #                                   ],
# #                    'Instrument' => 'Operetta',
# #                    'Sex' => [
# #                               'female'
# #                             ],
# #                    'Assay' => 'High content imaging',
# #                    'Archive' => undef,
# #                    'Description' => 'High content fluorescence microscopy',
# #                    'File download' => 'https://idr.openmicroscopy.org/webclient/?show=plate-6114',
# #                    'Accession' => 'experiment_20'
# #                  }
# ######## <-- The end ########
