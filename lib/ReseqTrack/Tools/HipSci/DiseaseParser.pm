package ReseqTrack::Tools::HipSci::DiseaseParser;

use strict;
use warnings;

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(fix_disease_from_spreadsheet get_ontology_full get_ontology_short get_disease_for_elasticsearch);

use List::Util qw(first);


my %spreadsheet_map = (
  bbs => 'bardet-biedl syndrome',
  nd => 'monogenic diabetes',
  normal => 'normal',
  ataxia => 'rare hereditary ataxia',
  usher => 'usher syndrome and congenital eye defects',
  kabuki => 'kabuki syndrome',
  alport => 'alport syndrome',
  bpd => 'bleeding and platelet disorder',
  pid => 'primary immune deficiency',
  'battens disease' => 'batten disease',
  'macular dystrophy' => 'genetic macular dystrophy',
  'herediatary spastic paraplegia' => 'hereditary spastic paraplegia',
  'childhood neurology' => 'rare genetic neurological disorder',
);

our @diseases = (
  {
    regex => qr/normal/i,
    ontology_full => 'http://purl.obolibrary.org/obo/PATO_0000461',
    ontology_short => 'PATO:0000461',
    for_elasticsearch => 'Normal',
  },
  {
    regex => qr/bardet-/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_110',
    ontology_short => 'Orphanet:110',
    for_elasticsearch => 'Bardet-Biedl syndrome',
  },
  {
    regex => qr/diabetes/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_552',
    ontology_short => 'Orphanet:552',
    for_elasticsearch => 'Monogenic diabetes',
  },
  {
    regex =>  qr/ataxia/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_183518',
    ontology_short => 'Orphanet:183518',
    for_elasticsearch => 'Rare hereditary ataxia',
  },
  {
    regex => qr/usher/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_886',
    ontology_short => 'Orphanet:886',
    for_elasticsearch => 'Usher syndrome and congenital eye defects',
  },
  {
    regex => qr/kabuki/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_2322',
    ontology_short => 'Orphanet:2322',
    for_elasticsearch => 'Kabuki syndrome',
  },
  {
    regex => qr/cardiomyopathy/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_217569',
    ontology_short => 'Orphanet:217569',
    for_elasticsearch => 'Hypertrophic cardiomyopathy',
  },
  {
    regex => qr/alport/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_63',
    ontology_short => 'Orphanet:63',
    for_elasticsearch => 'Alport syndrome',
  },
  {
    regex => qr/bleeding/i,
    ontology_full => 'http://www.ebi.ac.uk/efo/EFO_0005803',
    ontology_short => 'EFO:0005803',
    for_elasticsearch => 'Bleeding and platelet disorder',
  },
  {
    regex => qr/primary immune deficiency/i,
    ontology_full => 'http://www.ebi.ac.uk/efo/EFO_0000540',
    ontology_short => 'EFO:0000540',
    for_elasticsearch => 'Primary immune deficiency',
  },
  {
    regex => qr/batten/i,
    ontology_full => 'http://purl.obolibrary.org/obo/DOID_0050756',
    ontology_short => 'DOID:0050756',
    for_elasticsearch => 'Batten disease',
  },
  {
    regex => qr/retinitis pigmentosa/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_791',
    ontology_short => 'Orphanet:791',
    for_elasticsearch => 'Retinitis pigmentosa',
  },
  {
    regex => qr/macular dystrophy/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_98664',
    ontology_short => 'Orphanet:98664',
    for_elasticsearch => 'Genetic macular dystrophy',
  },
  {
    regex => qr/spastic paraplegia/i,
    ontology_full => 'http://purl.obolibrary.org/obo/HP_0001258',
    ontology_short => 'HP:0001258',
    for_elasticsearch => 'Hereditary spastic paraplegia',
  },
  {
    regex => qr/congenital hyperins/i,
    ontology_full => 'http://purl.obolibrary.org/obo/OMIT_0023511',
    ontology_short => 'OMIT:0023511',
    for_elasticsearch => 'Congenital hyperinsulinism',
  },
  {
    regex => qr/neurological disorder/i,
    ontology_full => 'http://www.orpha.net/ORDO/Orphanet_71859',
    ontology_short => 'Orphanet:71859',
    for_elasticsearch => 'Rare genetic neurological disorder',
  },
);

sub fix_disease_from_spreadsheet {
  my ($from_disease) = @_;
  return undef if !$from_disease;
  return $spreadsheet_map{lc($from_disease)} // lc($from_disease);
}

sub get_ontology_full {
  my ($disease_string) = @_;
  my $disease_hash = first{$disease_string =~ $_->{regex}} @diseases;
  return undef if !$disease_hash;
  return $disease_hash->{ontology_full};
}

sub get_ontology_short {
  my ($disease_string) = @_;
  my $disease_hash = first{$disease_string =~ $_->{regex}} @diseases;
  return undef if !$disease_hash;
  return $disease_hash->{ontology_short};
}

sub get_disease_for_elasticsearch {
  my ($disease_string) = @_;
  my $disease_hash = first{$disease_string =~ $_->{regex}} @diseases;
  return undef if !$disease_hash;
  return $disease_hash->{for_elasticsearch};
}


