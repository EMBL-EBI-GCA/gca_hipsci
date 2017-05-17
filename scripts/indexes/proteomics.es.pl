#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::DBSQL::DBAdaptor;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::DiseaseParser qw(get_disease_for_elasticsearch);
use ReseqTrack::Tools::HipSci::Peptracker qw(exp_design_to_pep_ids);
use LWP::UserAgent;
use JSON qw(decode_json);
use Data::Compare;
use POSIX qw(strftime);
use File::Basename qw(dirname);
use File::Find qw();

my $es_host='ves-hx-e4:9200';
my $description = 'Mass spectrometry';
my @datasets;
my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';

&GetOptions(
    'es_host=s' => \$es_host,
    'dataset=s' => \@datasets,
    'dbhost=s'      => \$dbhost,
    'dbname=s'      => \$dbname,
    'dbuser=s'      => \$dbuser,
    'dbpass=s'      => \$dbpass,
    'dbport=s'      => \$dbport,
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

my $ua = LWP::UserAgent->new;

my %docs;
foreach my $dataset (@datasets) {
  my $project_res = $ua->get(sprintf('http://www.ebi.ac.uk/pride/ws/archive/project/%s', $dataset));
  die $project_res->status_line if !$project_res->is_success;
  my $project_hash = decode_json($project_res->decoded_content);

  my $file_res = $ua->get(sprintf('http://www.ebi.ac.uk/pride/ws/archive/file/list/project/%s', $dataset));
  die $file_res->status_line if !$file_res->is_success;
  my $file_hash = decode_json($file_res->decoded_content);

  my ($tsv_file) = grep {$_->{fileName} =~ /sample_index.*\.tsv/} @{$file_hash->{list}};
  die 'did not find sample index file' if !$tsv_file;
  my $tsv_res = $ua->get($tsv_file->{downloadLink});
  die $tsv_res->status_line if !$tsv_res->is_success;

  my %samples;
  my %peptracker_samples;

  TSV_ROW:
  foreach my $row (split("\n", $tsv_res->decoded_content)) {
    next TSV_ROW if !$row;
    my @cols = split("\t", $row);
    next TSV_ROW if $cols[0] !~ /^PT[A-Z0-9]+$/;
    #next TSV_ROW if $cols[1] !~ /^HPSI[0-9]{4}[a-z]{1,2}-[a-z]{4}(?:_\d+)?$/;
    my $cell_type = $cols[3] =~ /induced pluripotent/i ? 'iPSC' : $cols[3];
    my %sample = (
      name => $cols[1],
      bioSamplesAccession => $cols[2] || '',
      cellType => $cell_type,
    );
    if (my $growing_conditions = $cols[6]) {
      $sample{growingConditions} = ucfirst($growing_conditions);
    }
    if (my $sex = $cols[8]) {
      $sample{sex} = $sex;
    }
    if (my $disease_status = $cols[9]) {
      my $es_disease = get_disease_for_elasticsearch($cols[9]);
      die "did not recognise disease $disease_status" if !$es_disease;
      $sample{diseaseStatus} = $es_disease;
    }
    if (my $passage = $cols[10]) {
      $sample{passageNumber} = $passage;
    }
    $samples{$cols[1]} //= \%sample;
    push(@{$peptracker_samples{$cols[0]}}, \%sample);
  }

  my %raw_files;
  my @search_files;
  FILE:
  foreach my $file (@{$file_hash->{list}}) {
    next FILE if ! scalar grep {$file->{fileType} eq $_} qw(SEARCH RAW);
    my $db_files = $fa->fetch_by_filename($file->{fileName});
    die 'Unexpected number of files with name '.$file->{fileName} if @$db_files != 1;
    my $db_file = $db_files->[0];
    $file->{md5} = $db_file->md5;
    $file->{local_path} = $db_file->name;
    if ($file->{fileType} eq 'RAW') {
      my ($dundee_id) = $file->{fileName} =~ /(PT[A-Z0-9]+)/;
      die 'did not recognise dundee_id '.$db_file->name if !$dundee_id;

      next FILE if $db_file->name !~ m{/HPSI\d{4}[a-z]{1,2}-[a-z]{4}(?:_\d+)?/};

      if ($file->{fileName} =~ /\.raw/) {
        push(@{$raw_files{$dundee_id}{raw}}, $file);
      }
      elsif ($file->{fileName} =~ /\.mzML/) {
        push(@{$raw_files{$dundee_id}{mzML}}, $file);
      }
      else {
        die 'unrecognised file type for '.$file->{fileName};
      }
    }
    else {
      push(@search_files, $file);
    }
  }

  while (my ($dundee_id, $ext_files) = each %raw_files) {
    my $samples = $peptracker_samples{$dundee_id} || die "did not recognise $dundee_id";
    while (my ($ext, $raw_files) = each %$ext_files) {
      my $es_id = join('-', $dataset, 'proteomics', $ext, $dundee_id);
      $es_id =~ s/\s/_/g;
      $docs{$es_id} = {
        description => "$description $ext",
        files => [
        ],
        archive => {
          name => 'PRIDE',
          url => "http://www.ebi.ac.uk/pride/archive/projects/$dataset",
          ftpUrl => "ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2016/06/$dataset",
          openAccess => 1,
          accession => $dataset,
          accessionType => 'PROJECT_ID',
        },
        samples => $samples,
        assay => {
          type => 'Proteomics',
          instrument => join(',', @{$project_hash->{instrumentNames}}),
        }
      };
      foreach my $file (@$raw_files) {
        push(@{$docs{$es_id}{files}}, {
          name => $file->{fileName},
          md5 => $file->{md5},
          type => $ext
        });
      }
    }
  }

  while (my ($i, $search_file) = each @search_files) {
    my $es_id = join('-', $dataset, 'proteomics', 'search', $i);
    $es_id =~ s/\s/_/g;
    my $search_type = $search_file->{fileName} =~ /maxquant/i ? 'MaxQuant'
              : die 'did not recognise search type '.$search_file->{fileName};

    my $exp_design_file;
    File::Find::find(sub{
      return if $_ !~ /\.experimentalDesign/;
      $exp_design_file = $File::Find::name;
    }, dirname($search_file->{local_path}));
    die 'did not find experimentalDesign file for '.$search_file->{fileName} if !$exp_design_file;
    my %search_samples;
    foreach my $pep_id (@{exp_design_to_pep_ids($exp_design_file)}) {
      my $samples = $peptracker_samples{$pep_id} || die "did not recognise $pep_id";
      foreach my $sample (@$samples) {
        $search_samples{$sample->{name}} = $sample;
      }
    }
    my @search_samples = grep {$_->{name} =~ /HPSI\d{4}[a-z]{1,2}-[a-z]{4}(?:_\d+)?/ } values %search_samples;

    $docs{$es_id} = {
      description => "$description $search_type",
      files => [{
        name => $search_file->{fileName},
        md5 => $search_file->{md5},
        type => $search_type,
      }],
      archive => {
        name => 'PRIDE',
        url => "http://www.ebi.ac.uk/pride/archive/projects/$dataset",
        ftpUrl => "ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2016/06/$dataset",
        openAccess => 1,
        accession => $dataset,
        accessionType => 'PROJECT_ID',
      },
      samples => \@search_samples,
      assay => {
        type => 'Proteomics',
        instrument => join(',', @{$project_hash->{instrumentNames}}),
      }
    };
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
            'assay.type' => 'Proteomics',
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

