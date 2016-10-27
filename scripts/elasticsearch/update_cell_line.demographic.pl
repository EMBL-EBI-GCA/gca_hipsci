#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Text::Capitalize qw();
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my ($demographic_filename, $sex_filename);

&GetOptions(
  'es_host=s' =>\@es_host,
  'demographic_file=s' => \$demographic_filename,
  'sex_sequenome_file=s' => \$sex_filename,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}
die "did not get a demographic file on the command line" if !$demographic_filename;
die "did not get a sex sequenome file on the command line" if !$sex_filename;

my $cell_updated = 0;
my $cell_uptodate = 0;
my $donor_updated = 0;
my $donor_uptodate = 0;

my $cgap_donors = read_cgap_report()->{donors};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename, sex_sequenome_file => $sex_filename);

my %donors;
my %all_updates_donor;
my %all_update_cellline;

my %cgap_donors_hash;
DONOR:
foreach my $donor (@{$cgap_donors}) {
  next DONOR if !$donor->biosample_id;
  $cgap_donors_hash{$donor->biosample_id}=$donor;
}

my $scroll = $elasticsearch{$es_host[0]}->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
);

DONOR:
while ( my $doc = $scroll->next ) {
  my $donor = $cgap_donors_hash{$$doc{'_source'}{'bioSamplesAccession'}};
  my $donor_name = $$doc{'_source'}{'name'};
  my $donor_update = {};
  my $cell_line_update = {};
  if (my $disease = $donor->disease) {
    my $purl = $disease eq 'normal' ? 'http://purl.obolibrary.org/obo/PATO_0000461'
                : $disease =~ /bardet-/ ? 'http://www.orpha.net/ORDO/Orphanet_110'
                : $disease eq 'monogenic diabetes' ? 'http://www.orpha.net/ORDO/Orphanet_552'
                : $disease eq 'rare hereditary ataxia' ? 'http://www.orpha.net/ORDO/Orphanet_183518'
                : $disease eq 'usher syndrome' ? 'http://www.orpha.net/ORDO/Orphanet_886'
                : $disease eq 'kabuki syndrome' ? 'http://www.orpha.net/ORDO/Orphanet_2322'
                : $disease eq 'hypertrophic cardiomyopathy' ? 'http://www.orpha.net/ORDO/Orphanet_217569'
                : $disease eq 'alport syndrome' ? 'http://www.orpha.net/ORDO/Orphanet_63'
                : $disease eq 'bleeding and platelet disorder' ? 'http://www.ebi.ac.uk/efo/EFO_0005803'
                : $disease eq 'primary immune deficiency' ? 'http://www.ebi.ac.uk/efo/EFO_0000540'
                : $disease eq 'batten disease' ? 'http://purl.obolibrary.org/obo/DOID_0050756'
                : $disease eq 'retinitis pigmentosa' ? 'http://www.orpha.net/ORDO/Orphanet_791'
                : $disease eq 'genetic macular dystrophy' ? 'http://www.orpha.net/ORDO/Orphanet_98664'
                : $disease eq 'hereditary spastic paraplegia' ? 'http://purl.obolibrary.org/obo/HP_0001258'
                : $disease eq 'congenital hyperinsulinia' ? 'http://purl.obolibrary.org/obo/OMIT_0023511'
                : $disease eq 'rare genetic neurological disorder' ? 'http://www.orpha.net/ORDO/Orphanet_71859'
                : die "did not recognise disease $disease";
    my $disease_value = $disease eq 'normal' ? 'Normal'
                : $disease =~ /bardet-/ ? 'Bardet-Biedl syndrome'
                : $disease eq 'monogenic diabetes' ? 'Monogenic diabetes'
                : $disease eq 'rare hereditary ataxia' ? 'Rare hereditary ataxia'
                : $disease eq 'usher syndrome' ? 'Usher syndrome'
                : $disease eq 'kabuki syndrome' ? 'Kabuki syndrome'
                : $disease eq 'hypertrophic cardiomyopathy' ? 'Hypertrophic cardiomyopathy'
                : $disease eq 'alport syndrome' ? 'Alport syndrome'
                : $disease eq 'bleeding and platelet disorder' ? 'Bleeding and platelet disorder'
                : $disease eq 'primary immune deficiency' ? 'Primary immune deficiency'
                : $disease eq 'batten disease' ? 'Batten disease'
                : $disease eq 'retinitis pigmentosa' ? 'Retinitis pigmentosa'
                : $disease eq 'genetic macular dystrophy' ? 'Genetic macular dystrophy'
                : $disease eq 'hereditary spastic paraplegia' ? 'Hereditary spastic paraplegia'
                : $disease eq 'congenital hyperinsulinia' ? 'Congenital hyperinsulinism'
                : $disease eq 'rare genetic neurological disorder' ? 'Rare genetic neurological disorder'
                : die "did not recognise disease $disease";

    $donor_update->{diseaseStatus} = {
      value => $disease_value,
      ontologyPURL => $purl,
    };
    $cell_line_update->{diseaseStatus} = $donor_update->{diseaseStatus};
  }
  if (my $sex = $donor->gender) {
    my %sex_hash = (
      value => ucfirst($sex),
      ontologyPURL => $sex eq 'male' ? 'http://www.ebi.ac.uk/efo/EFO_0001266'
                      : $sex eq 'female' ? 'http://www.ebi.ac.uk/efo/EFO_0001265'
                      : undef,
    );
    $donor_update->{sex} = \%sex_hash;
    $cell_line_update->{donor}{sex} = \%sex_hash;
  }
  if (my $age = $donor->age) {
    $donor_update->{age} = $age;
    $cell_line_update->{donor}{age} = $age;
  }
  if (my $ethnicity = $donor->ethnicity) {
    $ethnicity = Text::Capitalize::capitalize($ethnicity);
    $donor_update->{ethnicity} = $ethnicity;
    $cell_line_update->{donor}{ethnicity} = $ethnicity;
  }
  $all_updates_donor{$$doc{'_source'}{'name'}} = $donor_update;
  $all_update_cellline{$$doc{'_source'}{'name'}} = $cell_line_update;
}

while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
  my $cell_updated = 0;
  my $cell_uptodate = 0;
  my $donor_updated = 0;
  my $donor_uptodate = 0;
  my $scroll = $elasticsearchserver->call('scroll_helper',
  index       => 'hipsci',
  type        => 'donor',
  search_type => 'scan',
  size        => 500
  );
  while ( my $doc = $scroll->next ) {
    my $donor_update = $all_updates_donor{$$doc{'_source'}{'name'}};
    my $cell_line_update = $all_update_cellline{$$doc{'_source'}{'name'}};
    my $donor = $cgap_donors_hash{$$doc{'_source'}{'bioSamplesAccession'}};
    my $update = clone $doc;
    delete $$update{'_source'}{'diseaseStatus'};
    delete $$update{'_source'}{'sex'};
    delete $$update{'_source'}{'age'};
    delete $$update{'_source'}{'ethnicity'};
    foreach my $field (keys %$donor_update){
      $$update{'_source'}{$field} = $$donor_update{$field};
    }
    if (Compare($$update{'_source'}, $$doc{'_source'})){
      $donor_uptodate++;
    }else{ 
      $$update{'_source'}{'_indexUpdated'} = $date;
        $elasticsearchserver->index_donor(id => $$doc{'_source'}{'name'}, body => $$update{'_source'});
      $donor_updated++;
    }
    foreach my $tissue (@{$donor->tissues}) {
      CELL_LINE:
      foreach my $cell_line(map {$_->name} $tissue, @{$tissue->ips_lines}){
        my $line_exists = $elasticsearchserver->call('exists',
          index => 'hipsci',
          type => 'cellLine',
          id => $cell_line,
        );
        next CELL_LINE if !$line_exists;
        my $original = $elasticsearchserver->fetch_line_by_name($cell_line);
        my $update = clone $original;
        delete $$update{'_source'}{'diseaseStatus'};
        delete $$update{'_source'}{'donor'}{'sex'};
        delete $$update{'_source'}{'donor'}{'age'};
        delete $$update{'_source'}{'donor'}{'ethnicity'};
        if (! scalar keys $$update{'_source'}{'donor'}){
          delete $$update{'_source'}{'donor'};
        }
        foreach my $field (keys %$cell_line_update){
          foreach my $subfield (keys $$cell_line_update{$field}){
            $$update{'_source'}{$field}{$subfield} = $$cell_line_update{$field}{$subfield};
          }     
        }
        if (Compare($$update{'_source'}, $$original{'_source'})){
          $cell_uptodate++;
        }else{
          $$update{'_source'}{'_indexUpdated'} = $date;
          $elasticsearchserver->index_line(id => $cell_line, body => $$update{'_source'});
          $cell_updated++;
        }
      }
    }
  }
  print "\n$host\n";
  print "03_update_demographics\n";
  print "Cell lines: $cell_updated updated, $cell_uptodate unchanged.\n";
  print "Donors: $donor_updated updated, $donor_uptodate unchanged.\n";
}
