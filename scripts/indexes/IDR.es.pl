
use warnings;
use strict;
use JSON::MaybeXS;

# use Getopt::Long;
# use Search::Elasticsearch;
# use ReseqTrack::DBSQL::DBAdaptor;
# use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
# use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
# use ReseqTrack::Tools::HipSci::ElasticsearchClient;
# use File::Basename qw(dirname);
# use Data::Compare;
# use POSIX qw(strftime);
# use WWW::Mechanize;
use JSON::MaybeXS qw(encode_json decode_json);
# use JSON -support_by_pp;
use Data::Dumper;

# my $es_host='ves-hx-e3:9200'; # eleasticserach
# my $dbhost = 'mysql-g1kdcc-public';  # eleasticserach
# my $demographic_filename; # not sure
# my $dbuser = 'g1kro'; # eleasticserach
# my $dbpass;
# my $dbport = 4197;
# my $dbname = 'hipsci_track';
# my $trim = '/nfs/hipsci';
# my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
# my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
# my $line = "https://idr.openmicroscopy.org/webclient/?show=plate-6101";
# add this file to the home directory.
# my $json_file = '/Users/amirp/Documents/apax_tasks/hipsci_IDR_data/IDR_API_Python/IDR_data/IDR_json_data.json';
my $json_file = '/homes/hipdcc/IDR_data/IDR_json_data.json';
open my $fh, '<', $json_file or die "could not open $json_file $!";
print Dumper($fh);
#
# #  NEW
# # my $description = 'Varient Effect Predictor multiple cell lines';
# my $description = 'Image Data Resource';  # it is important to add this so the search can be done on this.
# #  NEW
# # my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
# my $file_pattern = 'IDR';
# #  NEW
# my $test_cell_line = "HPSI0713i-qimz_1";
# # my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';
#
# my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
#
# my $db = ReseqTrack::DBSQL::DBAdaptor->new(  # probably dont need it
#   -host => $dbhost,
#   -user => $dbuser,
#   -port => $dbport,
#   -dbname => $dbname,
#   -pass => $dbpass,
#     );
# my $fa = $db->get_FileAdaptor; # probably dont need it
# my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
# improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename); # improve_donors method
# my (%cgap_ips_line_hash, %cgap_tissues_hash);
# foreach my $cell_line (@$cgap_ips_lines) {   # not sure if we need this
#   $cgap_ips_line_hash{$cell_line->name} = $cell_line;
#   $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue;
# }
# my $date = '20190314';
# my $label = 'IDR';
# my %file_sets; # need to build a file hash!
#
# # no need to fetch anything from database. Here loads of information is collected from a database, like
# # 'name' => '/nfs/hipsci/vol1/ftp/data/vep_openaccess_bcf/chr11.bcf',
# # 'size' => '457795918', 'created' => '2018-09-06 12:37:25', 'dbID' => '59644',
# # 'updated' => '2018-09-06 13:14:45', 'type' => 'MISC', 'md5' => '186c0e5235891ea2cfdce6d7a4d25898'
# #  Not sure if this info is required. We can manually alocate some for testing.
#
# # Question for Peter: can we add something with extention IDR in database?
# foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {  # my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
#   # my $file_path = $file->name; #
#   my $file_path = "test/IDR";
#   next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
#   $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
#   push(@{$file_sets{$label}{files}}, $file);
# }
#
# my $file_path = "test/IDR";
# # I think we need these two lines from the above code:
# # my $file_sets{$label} //= {label => $label, date => $date, files => []};
# print Dumper($file_sets);
# # push(@{$file_sets{$label}{files}}, $file);
#
# # instead of building an array with all the celllines, we can manually build one for now.
# # open my $fh, '<', $sample_list ...
# # ......  push(@open_access_samples, $line)}
# my @open_access_samples = ($test_cell_line);
#
# # my %docs;
# FILE:
# # foreach my $file_set (values %file_sets) { # this is the hash that was defined before, then we had
# # $file_sets{$label}  which is $file_sets{'IDR'}  = .....,       this is only one probably, the same as vep...]
#
#
# # THis is what I have to build:
# $docs{$es_id} = {   # this is for array express
#     description => $file_description,
#     files           => [
#     ],
#     archive         => {
#         name          => 'ArrayExpress',
#         accession     => $dataset_id,
#         accessionType => 'EXPERIMENT_ID',
#         url           => 'http://www.ebi.ac.uk/arrayexpress/experiments/' . $dataset_id . '/',
#         ftpUrl        => 'ftp://ftp.ebi.ac.uk/pub/databases/microarray/data/experiment/' . $folderid . "/" . $dataset_id . '/',
#         openAccess    => 1,
#     },
#     samples         => [ {
#         name                => $cell_line,
#         bioSamplesAccession => ($cgap_ips_line ? $cgap_ips_line->biosample_id : $cgap_tissue->biosample_id),
#         cellType            => $cell_type,
#         diseaseStatus       => $disease,
#         sex                 => $cgap_tissue->donor->gender,
#         growingConditions   => $growing_conditions,
#     } ],
#
# $docs{$es_id} = {   # this is for vep_bcf
#     description => $description,
#     files       => \@files,
#     archive     => {
#         name       => 'HipSci FTP',
#         url        => "ftp://ftp.hipsci.ebi.ac.uk$dir",
#         ftpUrl     => "ftp://ftp.hipsci.ebi.ac.uk$dir",
#         openAccess => 1,
#     },
#     samples     => \@samples,
#     assay       => {
#         type        => 'Genotyping array',
#         description => [ 'SOFTWARE=SNP2HLA', 'PLATFORM=Illumina beadchip HumanCoreExome-12' ],
#         instrument  => 'Illumina beadchip HumanCoreExome-12',
#     }
# }
# }
