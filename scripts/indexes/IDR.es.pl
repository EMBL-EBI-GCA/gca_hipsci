
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
my $description = 'Varient Effect Predictor multiple cell lines';
my $file_pattern = 'vep_openaccess_bcf/chr%.bcf';
my $drop_trim = '/nfs/hipsci/vol1/ftp/data';
my $drop_base = '/nfs/research1/hipsci/drop/hip-drop/incoming';
# my $sample_list = '/nfs/research1/hipsci/drop/hip-drop/incoming/vep_openaccess_bcf/hipsci_openaccess_samples';

my $cell_line = "HPSI0713i-qimz_1";
my $line = "https://idr.openmicroscopy.org/webclient/?show=plate-6101";

