#!/usr/bin/env perl

use strict;

use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(dirname);
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use JSON;

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $json_file = 'dev_exp.json';
my $peptracker_id;

&GetOptions( 
	    'dbhost=s'      => \$dbhost,
	    'dbname=s'      => \$dbname,
	    'dbuser=s'      => \$dbuser,
	    'dbpass=s'      => \$dbpass,
	    'dbport=s'      => \$dbport,
	    'peptracker_id=s'      => \$peptracker_id,
    );


my $db = ReseqTrack::DBSQL::DBAdaptor->new(
  -host => $dbhost,
  -user => $dbuser,
  -port => $dbport,
  -dbname => $dbname,
  -pass => $dbpass,
    );

die("no peptracker_id") if (!$peptracker_id);
my $dundee_json = parse_json($json_file);
#foreach my $arg (@{$dundee_json->{sample_sets}}) {
  #use Data::Dumper; print Dumper $arg;
  #exit;
#}
my ($sample_set) = grep {$_->{sample_groups}->[0]->{samples}->[0]->{sample_identifier} =~ $peptracker_id} @{$dundee_json->{sample_sets}};
my $cell_line_short_name = $sample_set->{sample_groups}->[0]->{details}->{ips_cells}->[0]->{name};
die "did not get cell line short name" if !$cell_line_short_name;
my ($ips_line) = grep {$_->name =~ /${cell_line_short_name}$/} @{read_cgap_report()->{ips_lines}};
die "did not get cell line short name" if !$ips_line;
my $cell_line_name = $ips_line->name;
my $tissue = $ips_line->tissue;
my $donor = $tissue->donor;

my $fa = $db->get_FileAdaptor;
my $files = $fa->fetch_by_filename('%'.$peptracker_id.'%');
$files = [grep {$_->name !~ m{/withdrawn/}} @$files];
#print map {"$_\n"} map {$_->name} @$files;

my %files;
foreach my $file (sort {$a->name cmp $b->name} @$files) {
  my $file_name = $file->name;
  my $type = $file_name =~ /\.raw$/ ? 'raw'
          : $file_name =~ /\.mzML$/ ? 'mzML'
          : $file_name =~ m{/maxquant/} ? 'maxquant'
          : $file_name =~ /\.featureXML$/ ? 'featureXML'
          : $file_name =~ /\.csv$/ ? 'csv'
          : $file_name =~ /\.idXML$/ ? 'idXML'
          : die "did not recognise $file_name\n";
  push(@{$files{$type}}, {file_object=>$file});
}
my $current_file_id=0;
foreach my $type (qw( raw mzML maxquant featureXML csv idXML)) {
  foreach my $file (@{$files{$type}}) {
    $current_file_id += 1;
    $file->{pride_file_id} = $current_file_id;
  }
}
foreach my $file (@{$files{mzML}}) {
  my ($fraction) = $file->{file_object}->name =~ /(PTS\w+)\.mzML$/;
  my ($raw_file) = grep {$_->{file_object}->name =~ /$fraction.raw$/} @{$files{raw}};
  push(@{$file->{mapping}}, $raw_file->{pride_file_id});
}
foreach my $file (@{$files{maxquant}}) {
  push(@{$file->{mapping}}, map {$_->{pride_file_id}} @{$files{raw}});
}
foreach my $file (@{$files{featureXML}}) {
  my ($fraction) = $file->{file_object}->name =~ /(PTS\w+)\.featureXML$/;
  my ($mzml_file) = grep {$_->{file_object}->name =~ /$fraction.mzML$/} @{$files{mzML}};
  push(@{$file->{mapping}}, $mzml_file->{pride_file_id});
}
foreach my $file (@{$files{idXML}}) {
  my ($fraction) = $file->{file_object}->name =~ /\.(PTS\w+)\./;
  my ($featurexml_file) = grep {$_->{file_object}->name =~ /$fraction.featureXML$/} @{$files{featureXML}};
  push(@{$file->{mapping}}, $featurexml_file->{pride_file_id});
}
foreach my $file (@{$files{csv}}) {
  my ($fraction) = $file->{file_object}->name =~ /\.(PTS\w+)\./;
  my ($featurexml_file) = grep {$_->{file_object}->name =~ /$fraction.featureXML$/} @{$files{featureXML}};
  push(@{$file->{mapping}}, $featurexml_file->{pride_file_id});
}


print join("\t", 'MTD', 'submitter_name', 'Ian Streeter'), "\n";
print join("\t", 'MTD', 'submitter_mail', 'streeter@ebi.ac.uk'), "\n";
print join("\t", 'MTD', 'submitter_affiliation', 'EMBL-EBI'), "\n";
print join("\t", 'MTD', 'lab_head_name', 'Angus Lamond'), "\n";
print join("\t", 'MTD', 'lab_head_email', 'a.i.lamond@dundee.ac.uk'), "\n";
print join("\t", 'MTD', 'lab_head_affiliation', 'College of Life Sciences, University of Dundee'), "\n";
print join("\t", 'MTD', 'submitter_pride_login', '???'), "\n";
print join("\t", 'MTD', 'project_title', "HipSci IPS cell line $cell_line_name"), "\n";
print join("\t", 'MTD', 'project_description', 'HipSci brings together diverse constitutents in genomics, proteomics, cell biology and clinical genetics to create a UK national iPS cell resource and use it to carry out cellular genetic studies.'), "\n";
print join("\t", 'MTD', 'project_tag', 'HipSci'), "\n";
print join("\t", 'MTD', 'sample_processing_protocol', return_sample_procesesing_protocol()), "\n";
print join("\t", 'MTD', 'sample_processing_protocol', return_data_procesesing_protocol()), "\n";
print join("\t", 'MTD', 'other_omics_link', $ips_line->biosample_id), "\n";
print join("\t", 'MTD', 'keywords', 'Human, IPS cells, pluripotent'), "\n";
print join("\t", 'MTD', 'submission_type', 'COMPLETE'), "\n";
print join("\t", 'MTD', 'experiment_type', '[PRIDE, PRIDE:0000429, Shotgun proteomics,]'), "\n";
print join("\t", 'MTD', 'species', '[NEWT, 9606, Homo sapiens (Human),]'), "\n";
print join("\t", 'MTD', 'tissue', '[PRIDE, PRIDE:0000442, Tissue not applicable to dataset,]'), "\n";
print join("\t", 'MTD', 'cell_type', '[CL, CL:0001034, cell in vitro,]'), "\n";

#print join("\t", 'MTD', 'disease', '??????????'), "\n";

print join("\t", 'MTD', 'quantification', '????'), "\n";
print join("\t", 'MTD', 'instrument', '[MS, MS:1001911, Q Exactive,]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00400, deamidated residue, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00675, oxidized residue, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00696, phosphorylated residue, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00057, Acetyl, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00663, methylated lysine, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00670, N-acylated residue, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00658, methylated arginine, ]'), "\n";
print join("\t", 'MTD', 'modification', '[MOD, MOD:00040, 2-pyrrolidone-5-carboxylic acid (Gln), ]'), "\n";

print "\n";
print join("\t", 'FMH', 'file_id', 'file_type', 'file_path', 'file_mapping'), "\n";

foreach my $type (qw( raw mzML maxquant featureXML csv idXML)) {
  my $output_type = (raw=>'raw', mzML=>'raw', maxquant=>'quant', featureXML=>'peak', csv=>'quant', idxml=>'result');
  foreach my $file (@{$files{$type}}) {
    $file->{mapping} //= [];
    print join("\t", 'FME', $file->{pride_file_id}, $output_type, $file->{file_object}->name, join(',', @{$file->{mapping}})), "\n";
  }
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
  my $string = <<"PROTOCOL";
The frozen iPS cell pellets were solubilized using lysis buffer (8M urea, 100
mM TEAB). The cell lysates were digested using a two-step digestion protocol
(overnight Lys-C digestion followed by 4 hour-tryptic digestion). Two
chromatographic methods (Strong Anion eXchange (SAX) and Hydrophilic
Interactions Chromatography (HILIC) separations) were used to fractionate the
peptides for subsequent LC-MS/MS analyses.
PROTOCOL
  $string =~ s/\n//g;
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
  $string =~ s/\n//g;
  return $string;
}
