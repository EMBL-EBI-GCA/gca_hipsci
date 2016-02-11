#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::ElasticsearchClient;

my $es = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => 'ves-hx-e4:9200');

my %alleles = ( 0 => { 0 => 'E3', 1 => 'E2'}, 1 => { 0 => 'E4'});

print join("\t", qw(HipSci_name EBiSC_name access sex age ApoE)), "\n";

foreach my $cell_line (<>) {
  chomp $cell_line;
  my $es_line = $es->fetch_line_by_name($cell_line);
  die "$cell_line not found" if !$es_line;

  my $open_access = $es_line->{_source}{openAccess};

  my $genotypes = $open_access ? get_genotypes($cell_line) : undef;

  print join("\t", map {$_ || ''} $cell_line, $es_line->{_source}{ebiscName}, ($es_line->{_source}{openAccess} ? 'open' : 'managed'), $es_line->{_source}{donor}{sex}{value}, $es_line->{_source}{donor}{age}, $genotypes), "\n";

}

sub get_genotypes {
  my ($cell_line) = @_;
  my $dir = sprintf('/nfs/research2/hipsci/drop/hip-drop/tracked/gtarray/imputed_vcf/PRJEB11752/%s', $cell_line);
  return if ! -d $dir;
  opendir(DIR, $dir);
  my @files = grep (/\.vcf.gz$/, readdir(DIR));
  closedir(DIR);
  return if !@files;
  die @files if scalar @files >1;

  my (@rs7412, @rs429358);
  if (my $vcf_line = `tabix $dir/$files[0] 19:45412079-45412079`) {
    chomp $vcf_line;
    my $gt = (split("\t", $vcf_line))[9];
    @rs7412 = $gt =~ /^(\d)\|(\d)/;
  }
  else {return;}

  if (my $vcf_line = `tabix $dir/$files[0] 19:45411941-45411941`) {
    chomp $vcf_line;
    my $gt = (split("\t", $vcf_line))[9];
    @rs429358 = $gt =~ /^(\d)\|(\d)/;
  }
  else {return;}

  my $allele_1 =  $alleles{$rs429358[0]}{$rs7412[0]};
  my $allele_2 =  $alleles{$rs429358[1]}{$rs7412[1]};
  return join('|', sort ($allele_1, $allele_2));

}
