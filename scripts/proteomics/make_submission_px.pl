#!/usr/bin/env perl

use strict;

use ReseqTrack::DBSQL::DBAdaptor;
use File::Basename qw(dirname fileparse);
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use Getopt::Long;
use JSON;
use feature 'fc';

$| = 1;

my $dbhost = 'mysql-g1kdcc-public';
my $dbuser = 'g1kro';
my $dbpass;
my $dbport = 4197;
my $dbname = 'hipsci_private_track';
my $json_file = '/nfs/research1/hipsci/tracking_resources/dundee_peptracker/peptracker.json';
my $es_host='ves-pg-e3:9200';
my $peptracker_id;

&GetOptions( 
	    'dbhost=s'         => \$dbhost,
	    'dbname=s'         => \$dbname,
	    'dbuser=s'         => \$dbuser,
	    'dbpass=s'         => \$dbpass,
	    'dbport=s'         => \$dbport,
	    'json_file=s'      => \$json_file,
	    'peptracker_id=s'  => \$peptracker_id,
      'es_host=s'        => \$es_host,
    );

my $elasticsearch = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);

my %fasta_map = (
              #contaminant => '/nfs/research1/hipsci/drop/hip-drop/tracked/proteomics/databases/contaminant_proteins.fasta',
              #uniprot_120712 => '/nfs/research1/hipsci/drop/hip-drop/tracked/proteomics/databases/uniprot_human_120712.fasta',
              uniprot_120712 => '/nfs/research1/hipsci/drop/hip-drop/tracked/proteomics/databases/uniprot_sp_human_120712.contam.rev-nonsense.decoy.fasta',
              );
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

die("no peptracker_id") if (!$peptracker_id);
my $dundee_json = parse_json($json_file);
#foreach my $arg (@{$dundee_json->{sample_sets}}) {
  #use Data::Dumper; print Dumper $arg;
  #exit;
#}
my ($sample_set) = grep {$_->{sample_groups}->[0]->{samples}->[0]->{sample_identifier} =~ $peptracker_id} @{$dundee_json->{sample_sets}};
my $cell_line_name = $sample_set->{sample_groups}->[0]->{details}->{ips_cells}->[0]->{name};
die "did not get cell line name" if !$cell_line_name;
print $cell_line_name, "\n";

my $ips_line = $elasticsearch->call('search',(
  index => 'hipsci', type => 'cellLine',
  body => {
    query => {
      match => {
        'searchable.fixed' => $cell_line_name
      }
    }
  }
))->{hits}{hits}->[0];

my $donor = $elasticsearch->fetch_donor_by_name($ips_line->{_source}{donor}{name});
my $proteomics_files = $elasticsearch->call('search',(
  index => 'hipsci', type => 'file',
  body => {
    query => {
      filtered => {
        filter => {
          and => [
            {term => {
              'assay.type' => 'Proteomics'
            }},
            {term => {
              'samples.name' => $ips_line->{_source}{name}
            }},
          ]
        }
      }
    }
  }
));
my $proteomics_file = $proteomics_files->{hits}{hits}->[0];

my $fa = $db->get_FileAdaptor;
my $files = $fa->fetch_by_filename('%'.$peptracker_id.'%');
$files = [grep {$_->name !~ m{/withdrawn/}} @$files];
#print map {"$_\n"} map {$_->name} @$files;

$files = [grep {$_->name !~ m{/withdrawn/}} @$files];

my %used_fasta;
my %files;
FILE:
foreach my $file (sort {$a->name cmp $b->name} @$files) {
  my $file_name = $file->name;
  my $type = $file_name =~ /\.raw$/ ? 'raw'
          : $file_name =~ /\.mzML$/ ? 'mzML'
          : $file_name =~ m{/maxquant/} ? 'maxquant'
          : $file_name =~ /\.featureXML$/ ? 'featureXML'
          : $file_name =~ /\.csv$/ ? 'csv'
          : $file_name =~ /\.idXML$/ ? 'idXML'
          : $file_name =~ /\.mzid$/ ? 'mzid'
          : die "did not recognise $file_name\n";
  next FILE if $type eq 'maxquant' && $file_name !~ /\.zip$/;
  push(@{$files{$type}}, {file_object=>$file});
}
my $current_file_id=0;
foreach my $type (qw( raw mzML maxquant featureXML csv mzid)) {
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
  my $fasta_label = (split('\.', $file->{file_object}->filename()))[3];
  my $fasta = $fasta_map{$fasta_label} or die "did not recognise label $fasta_label";
  push(@{$used_fasta{$fasta}}, $file);
  #push(@{$used_fasta{$fasta_map{contaminant}}}, $file);
}
foreach my $file (@{$files{featureXML}}) {
  my ($fraction) = $file->{file_object}->name =~ /(PTS\w+)\.featureXML$/;
  my ($mzml_file) = grep {$_->{file_object}->name =~ /$fraction.mzML$/} @{$files{mzML}};
  push(@{$file->{mapping}}, $mzml_file->{pride_file_id});
}
foreach my $file (@{$files{mzid}}) {
  my ($fraction) = $file->{file_object}->name =~ /\.(PTS\w+)\./;
  my ($mzml_file) = grep {$_->{file_object}->name =~ /$fraction.mzML$/} @{$files{mzML}};
  push(@{$file->{mapping}}, $mzml_file->{pride_file_id});
  #my ($featurexml_file) = grep {$_->{file_object}->name =~ /$fraction.featureXML$/} @{$files{featureXML}};
  #push(@{$file->{mapping}}, $featurexml_file->{pride_file_id});
  #push(@{$file->{mapping}}, @{$featurexml_file->{mapping}});
  my $fasta_label = (split('\.', $file->{file_object}->filename))[3];
  my $fasta = $fasta_map{$fasta_label} or die "did not recognise label $fasta_label";
  push(@{$used_fasta{$fasta}}, $file);
  #push(@{$used_fasta{$fasta_map{contaminant}}}, $file);
}
foreach my $file (@{$files{csv}}) {
  my ($fraction) = $file->{file_object}->name =~ /\.(PTS\w+)\./;
  my ($featurexml_file) = grep {$_->{file_object}->name =~ /$fraction.featureXML$/} @{$files{featureXML}};
  push(@{$file->{mapping}}, $featurexml_file->{pride_file_id});
  push(@{$file->{mapping}}, @{$featurexml_file->{mapping}});
  my $fasta_label = (split('\.', $file->{file_object}->filename))[3];
  my $fasta = $fasta_map{$fasta_label} or die "did not recognise label $fasta_label";
  push(@{$used_fasta{$fasta}}, $file);
  #push(@{$used_fasta{$fasta_map{contaminant}}}, $file);
}

my %fasta_pride_ids;
while (my ($fasta, $file_list) = each %used_fasta) {
    $current_file_id += 1;
    $fasta_pride_ids{$current_file_id} = $fasta;
    foreach my $file (@$file_list) {
      push(@{$file->{mapping}}, $current_file_id);
    }
}




print join("\t", 'MTD', 'submitter_name', 'HipSci Project'), "\n";
print join("\t", 'MTD', 'submitter_mail', 'hipsci@ebi.ac.uk'), "\n";
print join("\t", 'MTD', 'submitter_affiliation', 'Human Induced Pluripotent Stem Cells Initiative'), "\n";
print join("\t", 'MTD', 'lab_head_name', 'Angus Lamond'), "\n";
print join("\t", 'MTD', 'lab_head_email', 'a.i.lamond@dundee.ac.uk'), "\n";
print join("\t", 'MTD', 'lab_head_affiliation', 'College of Life Sciences, University of Dundee'), "\n";
print join("\t", 'MTD', 'submitter_pride_login', 'hipsci@ebi.ac.uk'), "\n";
print join("\t", 'MTD', 'project_title', $ips_line->{_source}{name}." IPS cell line from HipSci"), "\n";
print join("\t", 'MTD', 'project_description', return_project_description(cell_line => $ips_line, donor => $donor, file => $proteomics_file)), "\n";
print join("\t", 'MTD', 'project_tag', 'HipSci'), "\n";
print join("\t", 'MTD', 'sample_processing_protocol', return_sample_procesesing_protocol(num_raw_files=>scalar @{$files{raw}})), "\n";
print join("\t", 'MTD', 'data_processing_protocol', return_data_procesesing_protocol()), "\n";
print join("\t", 'MTD', 'other_omics_link', 'http://www.ebi.ac.uk/biosamples/sample/'.$ips_line->{_source}{bioSamplesAccession}), "\n";
print join("\t", 'MTD', 'keywords', 'Human, IPS cells, pluripotent, HPLC fractionation (SAX), label free quantitative proteomics'), "\n";
print join("\t", 'MTD', 'submission_type', 'COMPLETE'), "\n";
print join("\t", 'MTD', 'experiment_type', '[PRIDE, PRIDE:0000429, Shotgun proteomics,]'), "\n";
print join("\t", 'MTD', 'species', '[NEWT, 9606, Homo sapiens (Human),]'), "\n";
print join("\t", 'MTD', 'tissue', '[PRIDE, PRIDE:0000442, Tissue not applicable to dataset,]'), "\n";
print join("\t", 'MTD', 'cell_type', '[CL, CL:0001034, cell in vitro,]'), "\n";

my $disease = $ips_line->{_source}{diseaseStatus}{value};
if (fc($disease) ne fc('normal')) {
  my $disease_id = $disease_map{lc($disease)};
  die "did not recognise disease $disease" if !$disease_id;
  print join("\t", 'MTD', 'disease', sprintf('[DOID, %s, %s]', $disease_id, $disease)), "\n";
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

foreach my $type (qw( raw mzML maxquant featureXML csv mzid)) {
  my $output_type = {raw=>'raw', mzML=>'raw', maxquant=>'search', featureXML=>'peak', csv=>'quantification', mzid=>'result'}->{$type};
  foreach my $file (@{$files{$type}}) {
    $file->{mapping} //= [];
    print join("\t", 'FME', $file->{pride_file_id}, $output_type, $file->{file_object}->filename, join(',', @{$file->{mapping}})), "\n";
  }
}
foreach my $fasta_id (sort {$a <=> $b} keys %fasta_pride_ids) {
    print join("\t", 'FME', $fasta_id, 'fasta', scalar fileparse($fasta_pride_ids{$fasta_id})), "\n";
}

print "\n";
my @SMH_headers = qw(SMH file_id species tissue cell_type instrument);
if (fc($disease) ne fc('normal')) {
  push(@SMH_headers, 'disease');
}
push(@SMH_headers, map {'modification'} @modifications);
print join("\t", @SMH_headers), "\n";

foreach my $file (@{$files{mzid}}) {
  print join("\t", 'SME', $file->{pride_file_id}, '[NEWT, 9606, Homo sapiens (Human),]',
      '[PRIDE, PRIDE:0000442, Tissue not applicable to dataset,]',
      '[CL, CL:0001034, cell in vitro,]',
      '[MS, MS:1001911, Q Exactive,]');
      if ($disease ne 'normal') {
        printf("\t[DOID, %s, %s,]", $disease, $disease_map{$disease})
      }
      print map {"\t$_"} @modifications;
      print "\n";
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
(overnight Lys-C digestion followed by 4 hour-tryptic digestion). %s was used to fractionate the
peptides for subsequent LC-MS/MS analyses.
PROTOCOL
$string = sprintf($string, $options{num_raw_files} == 16 ? 'Strong Anion eXchange (SAX) chromatography'
                        : $options{num_raw_files} == 23 ? 'Hydrophilic Interactions Chromatography (HILIC)'
                        : die 'did not recognise number of files '.$options{num_raw_files});
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
  my $es_cell_line = $options{cell_line};
  my $es_file = $options{file};
  my $es_donor = $options{donor};
  my $tissue_type = $es_cell_line->{_source}{sourceMaterial}{cellType};

  my ($growth_conditions) = map {$_->{growingConditions}} grep {$_->{name} eq $es_cell_line->{_source}{name}} @{$es_file->{_source}{samples}};
  my $string = <<"PROJECT";
%s is an induced pluripotent stem cell line generated by the HipSci project.
The tissue donor is %s%s with the disease state %s.
The iPS cell line was derived from %s by the %s method and grown on %s.
HipSci brings together diverse constituents in genomics, proteomics, cell biology and
clinical genetics to create a UK national iPS cell resource and use it to carry
out cellular genetic studies.
PROJECT
$string = sprintf($string, $es_cell_line->{_source}{name},
            $es_donor->{_source}{sex}{value},
            $es_donor->{_source}{age} ? sprintf(' in the age range %s years', $es_donor->{_source}{age}) : '',
            $es_donor->{_source}{diseaseStatus}{value},
            (fc($tissue_type) eq fc('fibroblast') ? 'fibroblasts' : $tissue_type),
            $es_cell_line->{_source}{reprogramming}{methodOfDerivation},
            ($growth_conditions =~ /feeder/i ? 'feeder cells' : 'E8 media'),
          );
  $string =~ s/\n/ /g;
  return $string;
}

