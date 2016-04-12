#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(dirname fileparse);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Getopt::Long;
use JSON;
use feature 'fc';
use List::MoreUtils qw(uniq);

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $json_file = 'dev_exp.json';
my $es_host='ves-oy-e3:9200';
my $maxquant_dir;
my $fasta;
my @other_files;

&GetOptions( 
	    'dbhost=s'      => \$dbhost,
	    'dbname=s'      => \$dbname,
	    'dbuser=s'      => \$dbuser,
	    'dbpass=s'      => \$dbpass,
	    'dbport=s'      => \$dbport,
	    'json_file=s'   => \$json_file,
            'es_host=s' => \$es_host,
            'maxquant_dir=s' => \$maxquant_dir,
            'fasta=s' => \$fasta,
            'other_file=s' => \@other_files,
    );

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my %disease_map = (
  'monogenic diabetes' => 'DOID:9351',
  'bardet-biedl syndrome' => 'DOID:1935',
);

my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );
my $fa = $db->get_FileAdaptor;

$maxquant_dir =~ s{/*$}{};
$maxquant_dir =~ s{^/}{};
my $maxquant_files = $fa->fetch_by_filename($maxquant_dir.'/%');

my %pep_ids;
my ($exp_design_file) = grep {$_->name =~ /experimentalDesign\.txt$/} @$maxquant_files;
open my $fh, '<', $exp_design_file->name or die "could not open ".$exp_design_file->name." $!";
<$fh>;
while (my $line = <$fh>) {
  chomp $line;
  my ($pep_id, $fraction) = split("\t", $line);
  $pep_id =~ s/-\d*$//;
  $pep_ids{$pep_id} //= [];
  push(@{$pep_ids{$pep_id}}, $fraction);
}
close $fh;

my $dundee_json = parse_json($json_file);

my ($zip_file) = grep {$_->name =~ /.tar.gz$/} @$maxquant_files;
$zip_file = {file_object=>$zip_file, mapping => [], type => 'maxquant'};

my @files;
my %biosample_ids;
my %diseases;
my $current_file_id=0;
PEP_ID:
foreach my $pep_id (keys %pep_ids) {

  foreach my $fraction (sort {$a <=> $b} @{$pep_ids{$pep_id}}) {
    my ($raw) = grep {$_->name !~ m{/withdrawn/}} @{$fa->fetch_by_filename($pep_id.'-'.$fraction.'.raw')};
    die "no raw file for $pep_id $fraction" if !$raw;
    $current_file_id += 1;
    my $raw_file_id = $current_file_id;
    push(@files, {file_object=>$raw, pride_file_id => $current_file_id, type => 'raw'});
    push(@{$zip_file->{mapping}}, $raw_file_id);

    my ($mzML) = grep {$_->name !~ m{/withdrawn/}} @{$fa->fetch_by_filename($pep_id.'-'.$fraction.'.mzML')};
    die "no mzML file for $pep_id $fraction" if !$mzML;
    $current_file_id += 1;
    push(@files, {file_object=>$mzML, pride_file_id => $current_file_id, mapping => [$raw_file_id], type => 'mzML'});
  }

  next PEP_ID if $pep_id eq 'PT4835';

  my ($sample_set) = grep {$_->{sample_groups}->[0]->{samples}->[0]->{sample_identifier} =~ $pep_id} @{$dundee_json->{sample_sets}};
  my $cell_line = $sample_set->{sample_groups}->[0]->{details}->{ips_cells}->[0]->{name} || $sample_set->{sample_groups}->[0]->{details}->{descriptive_name};
  die "did not get cell line name for $pep_id" if !$cell_line;
  $cell_line =~ s/\s.*$//;

  $cell_line = 'zumy' if $cell_line =~ /zumy/;
  $cell_line = 'qifc' if $cell_line =~ /qifc/;

  my $ips_line = $elasticsearch->call('search',(
    index => 'hipsci', type => 'cellLine',
    body => {
      query => {
        match => {
          'searchable.fixed' => $cell_line
        }
      }
    }
  ))->{hits}{hits}->[0];
  next PEP_ID if !$ips_line;
  $biosample_ids{$ips_line->{_source}{name}} = $ips_line->{_source}{bioSamplesAccession};
  $diseases{$ips_line->{_source}{diseaseStatus}{value}} = 1;
}
$current_file_id += 1;
$zip_file->{pride_file_id} = $current_file_id;
push(@files, $zip_file);

print join("\t", 'MTD', 'submitter_name', 'HipSci Project'), "\n";
print join("\t", 'MTD', 'submitter_mail', 'hipsci@ebi.ac.uk'), "\n";
print join("\t", 'MTD', 'submitter_affiliation', 'Human Induced Pluripotent Stem Cells Initiative'), "\n";
print join("\t", 'MTD', 'lab_head_name', 'Angus Lamond'), "\n";
print join("\t", 'MTD', 'lab_head_email', 'a.i.lamond@dundee.ac.uk'), "\n";
print join("\t", 'MTD', 'lab_head_affiliation', 'College of Life Sciences, University of Dundee'), "\n";
print join("\t", 'MTD', 'submitter_pride_login', 'hipsci@ebi.ac.uk'), "\n";
print join("\t", 'MTD', 'project_title', sprintf("HipSci project pilot submission for %s IPS cell lines", scalar keys %biosample_ids)), "\n";
print join("\t", 'MTD', 'project_description', return_project_description(num_cell_lines => scalar keys %biosample_ids)), "\n";
print join("\t", 'MTD', 'project_tag', 'HipSci'), "\n";
print join("\t", 'MTD', 'sample_processing_protocol', return_sample_procesesing_protocol()), "\n";
print join("\t", 'MTD', 'data_processing_protocol', return_data_procesesing_protocol()), "\n";

my %es_biosample_ids = ('CTRL1114es-zumy' => 'SAMEA3110364','CTRL0914es-qifc' => 'SAMEA3402864');
while (my ($cell_line, $biosample_id) = each %biosample_ids) {
  print join("\t", 'MTD', 'other_omics_link', sprintf('BioSamples link for %s: http://www.ebi.ac.uk/biosamples/sample/%s', $cell_line, $biosample_id)), "\n";
}
while (my ($cell_line, $biosample_id) = each %es_biosample_ids) {
  print join("\t", 'MTD', 'other_omics_link', sprintf('BioSamples link for %s: http://www.ebi.ac.uk/biosamples/sample/%s', $cell_line, $biosample_id)), "\n";
}

print join("\t", 'MTD', 'keywords', 'Human, IPS cells, pluripotent, HPLC fractionation (SAX), label free quantitative proteomics'), "\n";
print join("\t", 'MTD', 'submission_type', 'PARTIAL'), "\n";
print join("\t", 'MTD', 'experiment_type', '[PRIDE, PRIDE:0000429, Shotgun proteomics,]'), "\n";
print join("\t", 'MTD', 'species', '[NEWT, 9606, Homo sapiens (Human),]'), "\n";
print join("\t", 'MTD', 'tissue', '[PRIDE, PRIDE:0000442, Tissue not applicable to dataset,]'), "\n";
print join("\t", 'MTD', 'cell_type', '[CL, CL:0000010, cultured cell,]'), "\n";
print join("\t", 'MTD', 'cell_type', '[CL, CL:0002322, embryonic stem cell,]'), "\n";

foreach my $disease (keys %diseases) {
  if (fc($disease) ne fc('normal')) {
    my $disease_id = $disease_map{lc($disease)};
    die "did not recognise disease $disease" if !$disease_id;
    print join("\t", 'MTD', 'disease', sprintf('[DOID, %s, %s]', $disease_id, $disease)), "\n";
  }
}

my @modifications = (
    '[MOD, MOD:00400, deamidated residue, ]',
    '[MOD, MOD:00675, oxidized residue, ]',
    '[MOD, MOD:00696, phosphorylated residue, ]',
    '[MOD, MOD:00057, Acetyl, ]',
    '[MOD, MOD:00663, methylated lysine, ]',
    '[MOD, MOD:00670, N-acylated residue, ]',
    '[MOD, MOD:01060, S-carboxamidomethyl-L-cysteine, ]',
    #'[MOD, MOD:00658, methylated arginine, ]',
    #'[MOD, MOD:00040, 2-pyrrolidone-5-carboxylic acid (Gln), ]',
);

my @quantifications = (
    '[PRIDE, PRIDE:0000435, Peptide counting,]',
    '[PRIDE, PRIDE:0000436, Spectral counting,]',
    '[PRIDE, PRIDE:0000437, Protein Abundance Index ­ PAI,]',
);

foreach my $quantification (@quantifications) {
  print join("\t", 'MTD', 'quantification', $quantification), "\n";
}
print join("\t", 'MTD', 'instrument', '[MS, MS:1001911, Q Exactive,]'), "\n";
foreach my $modification (@modifications) {
  print join("\t", 'MTD', 'modification', $modification), "\n";
}

print "\n";
print join("\t", 'FMH', 'file_id', 'file_type', 'file_path', 'file_mapping'), "\n";

foreach my $file (@files) {
  my $output_type = {raw=>'raw', mzML=>'raw', maxquant=>'search', featureXML=>'peak', csv=>'quantification', mzid=>'result'}->{$file->{type}};
  $file->{mapping} //= [];
  print join("\t", 'FME', $file->{pride_file_id}, $output_type, $file->{file_object}->filename, join(',', @{$file->{mapping}})), "\n";
}
if ($fasta) {
  $current_file_id += 1;
  print join("\t", 'FME', $current_file_id, 'fasta', scalar fileparse($fasta), ''), "\n";
}
foreach my $other_file (@other_files) {
  $current_file_id += 1;
  print join("\t", 'FME', $current_file_id, 'other', scalar fileparse($other_file), ''), "\n";
}


sub parse_json {
  my ($json_file) = @_;
  open my $IN, '<', $json_file or die "could not open $json_file $!";
  local $/ = undef;
  my $json = <$IN>;
  close $IN;
  my $decoded_json = JSON->new->utf8->decode($json);
  return $decoded_json;
}

sub return_sample_procesesing_protocol {
  my (%options) = @_;
  my $string = <<"PROTOCOL";
The frozen iPS cell pellets were solubilized using lysis buffer (8M urea, 100
mM TEAB). The cell lysates were digested using a two-step digestion protocol
(overnight Lys-C digestion followed by 4 hour-tryptic digestion). Strong Anion eXchange (SAX) chromotography was used to fractionate the
peptides for subsequent LC-MS/MS analyses.
PROTOCOL
  $string =~ s/\n/ /g;
  return $string;
}

sub return_data_procesesing_protocol {
  my $string = <<"PROTOCOL";
Proteomics analyses were performed using Q-exactive mass spectrometer and the
data processing were carried out using Maxquant version 1.3.0.5. Data were
processed with the following settings: 2 missed cleavages allowed, enzyme used
was trypsin/P, 20 ppm tolerance was used for fragment ions, FDR cut off of 0.5
was used. One fixed modification: carbamidomethylation (Cys), and few variable
modifications were selected: Oxidation (M); Acetylation (N-term), deamidation
(NQ), pyroglutamate conversion of glutamine.
PROTOCOL
  $string =~ s/\n/ /g;
  return $string;
}

sub return_project_description {
  my (%options) = @_;
  my $num_cell_lines = $options{num_cell_lines};

  my $string = <<"PROJECT";
The Human Induced Pluripotent Stem Cells Initiative (HipSci) is generating a
large, high-quality reference panel of human IPSC lines. This is a pilot submission
of mass-spectrometry analyses from %s induced pluripotent stem cell lines generated
by the HipSci project. This submission includes also data for two embryonic stem
cell lines, and one reference sample comprising a mixture of 42 IPSC lines.

PROJECT
$string = sprintf($string, $num_cell_lines);
  $string =~ s/\n/ /g;
  return $string;
}

