
use warnings;
use strict;

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
my $description = 'Image Data Resource';  # it is important to add this so the search
# can be done on this.
my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
# my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';

my $test_cell_line = "HPSI0713i-qimz_1";
my $line = "https://idr.openmicroscopy.org/webclient/?show=plate-6101";
my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my $db = ReseqTrack::DBSQL::DBAdaptor->new(  # probably dont need it
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor; # probably dont need it
my ($cgap_ips_lines, $cgap_tissues, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines tissues donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename); # improve_donors method
my (%cgap_ips_line_hash, %cgap_tissues_hash);
foreach my $cell_line (@$cgap_ips_lines) {   # not sure if we need this
  $cgap_ips_line_hash{$cell_line->name} = $cell_line;
  $cgap_tissues_hash{$cell_line->tissue->name} = $cell_line->tissue;
}
my $date = '20190314';
my $label = 'IDR';
my %file_sets; # need to build a file hash!

# no need to fetch anything from database. Here loads of information is collected from a database, like
# 'name' => '/nfs/hipsci/vol1/ftp/data/vep_openaccess_bcf/chr11.bcf',
# 'size' => '457795918', 'created' => '2018-09-06 12:37:25', 'dbID' => '59644',
# 'updated' => '2018-09-06 13:14:45', 'type' => 'MISC', 'md5' => '186c0e5235891ea2cfdce6d7a4d25898'
#  Not sure if this info is required. We can manually alocate some for testing.
# foreach my $file (@{$fa->fetch_by_filename($file_pattern)}) {  # my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
#   my $file_path = $file->name; #
#   next FILE if $file_path !~ /$trim/ || $file_path =~ m{/withdrawn/};
#   $file_sets{$label} //= {label => $label, date => $date, files => [], dir => dirname($file_path)};
#   push(@{$file_sets{$label}{files}}, $file);
# }

my $file_path = "test/IDR";
# I think we need these two lines from the above code:
$file_sets{$label} = {label => $label, date => $date, files => []};
print Dumper($file_sets);
# push(@{$file_sets{$label}{files}}, $file);

# instead of building an array with all the celllines, we can manually build one for now.
# open my $fh, '<', $sample_list ...
# ......  push(@open_access_samples, $line)}
my @open_access_samples = ($test_cell_line);

# my %docs;
FILE:
# foreach my $file_set (values %file_sets) { # this is the hash that was defined before, then we had
# $file_sets{$label}  which is $file_sets{'IDR'}  = .....,       this is only one probably, the same as vep...]