#!/usr/bin/env perl

use strict;
use warnings;
use File::Find qw();
use ReseqTrack::Tools::HipSci::ElasticsearchClient;

=pod

=head1 NAME

$GCA_HIPSCI/scripts/file/check_cohort_directory.pl

=head1 SYNOPSIS

This script is for checking that all data files have been grouped together into the correct cohort directory.

WTSI requested that we run this script whenever they send data to us. It is important because these are the cohort directories which they use when they submit data to EGA.
By running this script we ensure that the correct DAC will be responsible for the correct data files.

The output is a list of files which have been grouped into the wrong cohort directory. You should hope to see no output.

=head1 Example

perl check_cohort_directory.pl

=cut

my @dirs = (
  '/nfs/research1/hipsci/controlled',
  '/nfs/research1/hipsci/drop/hip-drop/tracked/exomeseq',
  '/nfs/research1/hipsci/drop/hip-drop/tracked/rnaseq',
  '/nfs/research1/hipsci/drop/hip-drop/tracked/gexarray',
  '/nfs/research1/hipsci/drop/hip-drop/tracked/gtarray',
  '/nfs/research1/hipsci/drop/hip-drop/tracked/mtarray',
);

my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => 'ves-hx-e4:9200');

my %study_ids = (
  EGAS00001000866 => 'PATO_0000461',
  EGAS00001000867 => 'PATO_0000461',
  EGAS00001000865 => 'PATO_0000461',
  EGAS00001000592 => 'PATO_0000461',
  EGAS00001000593 => 'PATO_0000461',
  PRJEB11752 => 'PATO_0000461',
  'E-MTAB-4057' => 'PATO_0000461',
  'E-MTAB-4059' => 'PATO_0000461',
  ERP006946 => 'PATO_0000461',
  ERP007111 => 'PATO_0000461',

  EGAS00001001272 => 'Orphanet_110',
  EGAS00001001276 => 'Orphanet_110',
  EGAS00001001274 => 'Orphanet_110',
  EGAS00001000969 => 'Orphanet_110',
  EGAS00001001318 => 'Orphanet_110',

  EGAS00001001273 => 'EFO_1001511',
  EGAS00001001277 => 'EFO_1001511',
  EGAS00001001275 => 'EFO_1001511',
  EGAS00001001140 => 'EFO_1001511',
  EGAS00001001137 => 'EFO_1001511',

  EGAS00001002005 => 'Orphanet_183518',
  EGAS00001002020 => 'Orphanet_183518',
  EGAS00001002034 => 'Orphanet_183518',
  EGAS00001001978 => 'Orphanet_183518',
  EGAS00001001992 => 'Orphanet_183518',

  EGAS00001002006 => 'HP_0001258',
  EGAS00001002021 => 'HP_0001258',
  EGAS00001002035 => 'HP_0001258',
  EGAS00001001979 => 'HP_0001258',
  EGAS00001001991 => 'HP_0001258',

  EGAS00001002007 => 'Orphanet_2322',
  EGAS00001002022 => 'Orphanet_2322',
  EGAS00001002036 => 'Orphanet_2322',
  EGAS00001001981 => 'Orphanet_2322',
  EGAS00001001989 => 'Orphanet_2322',

  EGAS00001002008 => 'Orphanet_886',
  EGAS00001002023 => 'Orphanet_886',
  EGAS00001002037 => 'Orphanet_886',
  EGAS00001001985 => 'Orphanet_886',
  EGAS00001001997 => 'Orphanet_886',

  EGAS00001002009 => 'Orphanet_63',
  EGAS00001002024 => 'Orphanet_63',
  EGAS00001002038 => 'Orphanet_63',
  EGAS00001001974 => 'Orphanet_63',
  EGAS00001001986 => 'Orphanet_63',

  EGAS00001002010 => 'OMIT_0023511',
  EGAS00001002025 => 'OMIT_0023511',
  EGAS00001002039 => 'OMIT_0023511',
  EGAS00001001977 => 'OMIT_0023511',
  EGAS00001001988 => 'OMIT_0023511',

  EGAS00001002011 => 'Orphanet_217569',
  EGAS00001002026 => 'Orphanet_217569',
  EGAS00001002040 => 'Orphanet_217569',
  EGAS00001001980 => 'Orphanet_217569',
  EGAS00001001994 => 'Orphanet_217569',

  EGAS00001002012 => 'EFO_0000540',
  EGAS00001002027 => 'EFO_0000540',
  EGAS00001002041 => 'EFO_0000540',
  EGAS00001001983 => 'EFO_0000540',
  EGAS00001001990 => 'EFO_0000540',

  EGAS00001002013 => 'EFO_0005803',
  EGAS00001002028 => 'EFO_0005803',
  EGAS00001002042 => 'EFO_0005803',
  EGAS00001001976 => 'EFO_0005803',
  EGAS00001001993 => 'EFO_0005803',

  EGAS00001002014 => 'Orphanet_98664',
  EGAS00001002029 => 'Orphanet_98664',
  EGAS00001002043 => 'Orphanet_98664',
  EGAS00001001982 => 'Orphanet_98664',
  EGAS00001001995 => 'Orphanet_98664',

  EGAS00001002015 => 'Orphanet_791',
  EGAS00001002030 => 'Orphanet_791',
  EGAS00001002044 => 'Orphanet_791',
  EGAS00001001984 => 'Orphanet_791',
  EGAS00001001996 => 'Orphanet_791',

  EGAS00001002016 => 'DOID_0050756',
  EGAS00001002031 => 'DOID_0050756',
  EGAS00001002045 => 'DOID_0050756',
  EGAS00001001975 => 'DOID_0050756',
  EGAS00001001987 => 'DOID_0050756',

  EGAS00001002017 => 'Orphanet_71859',
  EGAS00001002032 => 'Orphanet_71859',
  EGAS00001002046 => 'Orphanet_71859',
  EGAS00001001999 => 'Orphanet_71859',
  EGAS00001002002  => 'Orphanet_71859',
);

my %donor_ont_id;

sub wanted {
  return if ! -d;
  /^HPSI[0-9]{4}[a-z]{1,2}-([a-z]{4})(?:_\d+)?/;
  return if !$&;
  my $line = $&;
  my ($study_dir) = $File::Find::name =~ m{([^/]*)/HPSI[0-9]{4}};
  die $File::Find::name if !$study_dir;
  die "unkown study $File::Find::name" if ! exists $study_ids{$study_dir};
  my ($donor_name) = $line =~ /-([a-z]{4})/;
  my $ont_term = $donor_ont_id{$donor_name};
  if (!$ont_term) {
    my $donor = $es->fetch_donor_by_short_name($donor_name, fuzzy => 1);
    die $donor_name if !$donor;
    ($ont_term) = $donor->{_source}{diseaseStatus}{ontologyPURL} =~ m{/([^/]*)$};
    die $donor_name if !$ont_term;
    $donor_ont_id{$donor_name} = $ont_term;
  }
  return if $study_ids{$study_dir} eq $ont_term;
  print $File::Find::name, "\n";
};

File::Find::find(\&wanted, @dirs);
