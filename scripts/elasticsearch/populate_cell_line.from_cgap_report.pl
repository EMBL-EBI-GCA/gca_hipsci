#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use Getopt::Long;
use BioSD;
use ReseqTrack::Tools::HipSci::ElasticsearchClient;
use ReseqTrack::Tools::HipSci::OverrideSelectedStatus;
use ReseqTrack::EBiSC::hESCreg;
use LWP::Simple qw(get);
use LWP::UserAgent;
use List::Util qw();
use Data::Compare;
use Clone qw(clone);
use POSIX qw(strftime);
use Data::Dumper;

my $date = strftime('%Y%m%d', localtime);

my @es_host;
my $ecacc_index_file;
my ($hESCreg_user, $hESCreg_pass);
&GetOptions(
    'es_host=s' =>\@es_host,
    'ecacc_index_file=s'      => \$ecacc_index_file,
    'hESCreg_user=s' => \$hESCreg_user,
    'hESCreg_pass=s' => \$hESCreg_pass,
);

my $cgap_ips_lines = read_cgap_report()->{ips_lines};
my %biomaterial_provider_hash = (
  'H1288' => 'Cambridge BioResource',
  '13_042' => 'Cambridge BioResource',
  '13_058' => 'University College London',
  '14_001' => 'University College London',
  '14_025' => 'University of Exeter Medical School',
  '14_036' => 'NIH Human Embryonic Stem Cell Registry',
  '15_097' => 'University College London',
  '15_098' => 'University College London',
  '15_099' => 'University of Manchester',
  '15_093' => 'University College London',
  '16_010' => 'University College London',
  '16_011' => 'University College London',
  '16_013' =>  'University College London',
  '16_057' =>  'University of Manchester',
  '16_015' =>  'Cambridge BioResource',
  '16_019' =>  'Cambridge BioResource',
  '16_027' =>  'University College London',
  '16_028' =>  'University College London',
  '16_030' =>  'University College London',
  '16_060' =>  'Cambridge BioResource',
  '16_059' =>  'Cambridge BioResource',
);
my %open_access_hash = (
  'H1288' => 0,
  '13_042' => 1,
  '13_058' => 0,
  '14_001' => 0,
  '14_025' => 0,
  '14_036' => 0,
  '15_097' => 0,
  '15_098' => 0,
  '15_099' => 0,
  '15_093' => 0,
  '16_010' => 0,
  '16_011' => 0,
  '16_013' => 0,
  '16_057' => 0,
  '16_015' => 0,
  '16_019' => 0,
  '16_027' => 0,
  '16_028' => 0,
  '16_030' => 0,
  '16_059' => 0,
  '16_060' => 0,
);

my %elasticsearch;
foreach my $es_host (@es_host){
  $elasticsearch{$es_host} = ReseqTrack::Tools::HipSci::ElasticsearchClient->new(host => $es_host);
}
my $osd = ReseqTrack::Tools::HipSci::OverrideSelectedStatus->instance;

print Dumper($hESCreg_user);
print Dumper($hESCreg_pass);

my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
);

#
# my %ebisc_names;
# LINE:
# foreach my $ebisc_name (@{$hESCreg->find_lines(url=>"/api/export/hipsci")}) {
#   next LINE if $ebisc_name !~ /^WTSI/;
#   my $line = eval{$hESCreg->get_line($ebisc_name);};
#   next LINE if !$line || $@;
#   next LINE if !$line->{biosamples_id};
#   $ebisc_names{$line->{biosamples_id}} = $ebisc_name;
# }
# my $ua = LWP::UserAgent->new();
#
#
# my %catalog_numbers;
# open my $fh, '<', $ecacc_index_file or die "could not open $ecacc_index_file $!";
# LINE:
# while (my $line = <$fh>) {
#   next LINE if $line =~ /^#/;
#   chomp $line;
#   my ($cell_line, $ecacc_cat_no) = split("\t", $line);
#   $catalog_numbers{$cell_line} = $ecacc_cat_no;
# }
# close $fh;
#
# my %all_samples;
# my %donors;
# CELL_LINE:
# foreach my $ips_line (@{$cgap_ips_lines}) {
#   next CELL_LINE if ! $ips_line->biosample_id;
#   next CELL_LINE if $ips_line->name !~ /^HPSI\d{4}i-/;
#   my $biosample = BioSD::fetch_sample($ips_line->biosample_id);
#   next CELL_LINE if !$biosample;
#   my $tissue = $ips_line->tissue;
#   my $donor = $tissue->donor;
#   my $donor_biosample = BioSD::fetch_sample($donor->biosample_id);
#   my $tissue_biosample = BioSD::fetch_sample($tissue->biosample_id);
#   next CELL_LINE if !$tissue_biosample || !$donor_biosample;
#   my $sample_index = {};
#   $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
#   next CELL_LINE if ! $sample_index->{name};
#   $sample_index->{'bioSamplesAccession'} = $ips_line->biosample_id;
#   $sample_index->{'donor'} = {name => $donor_biosample->property('Sample Name')->values->[0],
#                             bioSamplesAccession => $donor->biosample_id};
#
#   $sample_index->{'cellType'}->{value} = "iPSC";
#   $sample_index->{'cellType'}->{ontologyPURL} = "http://www.ebi.ac.uk/efo/EFO_0004905";
#
#   if (my $source_material = $tissue->tissue_type) {
#     $sample_index->{'sourceMaterial'} = { value => $source_material };
#   }
#   if (my $cell_type_property = $tissue_biosample->property('cell type')) {
#     my $cell_type_qual_val = $cell_type_property->qualified_values()->[0];
#     my $cell_type_purl = $cell_type_qual_val->term_source()->term_source_id();
#     if ($cell_type_purl !~ /^http:/) {
#       $cell_type_purl = $cell_type_qual_val->term_source()->uri() . $cell_type_purl;
#     }
#     if (ucfirst(lc($cell_type_qual_val->value())) eq "Pbmc"){
#       $sample_index->{'sourceMaterial'}->{cellType} = "PBMC";
#     }else{
#       $sample_index->{'sourceMaterial'}->{cellType} = ucfirst(lc($cell_type_qual_val->value()));
#     }
#     $sample_index->{'sourceMaterial'}->{ontologyPURL} = $cell_type_purl;
#   }
#
# =cut
#
#   if (my $qc1_release = List::Util::first {$_->is_qc1} @{$ips_line->release}) {
#     $sample_index->{'growingConditionsQC1'} = $qc1_release->is_feeder_free ? 'E8 media' : 'Feeder dependent';
#   }
#   if (my $qc2_release = List::Util::first {$_->is_qc2} @{$ips_line->release}) {
#     $sample_index->{'growingConditionsQC2'} = $qc2_release->is_feeder_free ? 'E8 media' : 'Feeder dependent';
#   }
#
# =cut
#
#   my $is_selected = ($ips_line->genomics_selection_status || $catalog_numbers{$sample_index->{name}}) ? 1 : 0;
#   my $bank_release = (List::Util::first {$_->type =~ /ecacc/i } @{$ips_line->release})
#                           || (List::Util::first {$_->type =~ /ebisc/i } @{$ips_line->release})
#                           || ($ips_line->genomics_selection_status ? (List::Util::first {$_->is_qc2 } @{$ips_line->release}) : undef);
#   if ($is_selected && !$bank_release) {
#     ($bank_release) = sort {$b->goal_time cmp $a->goal_time} @{$ips_line->release};
#   }
#   if ($bank_release) {
#
#     if ($bank_release->is_feeder_free) {
#       $sample_index->{'culture'} = {
#         medium => 'E8 media',
#         passageMethod => 'EDTA clump passaging',
#         surfaceCoating => 'vitronectin',
#         CO2 => '5%',
#         summary => 'Feeder-free',
#       };
#     }
#     else {
#       $sample_index->{'culture'} = {
#         medium => 'KOSR',
#         passageMethod => 'collagenase and dispase',
#         surfaceCoating => 'Mouse embryo fibroblast (MEF) feeder cells',
#         CO2 => '5%',
#         summary => 'Feeder-dependent',
#       };
#     }
#   }
#
#   if (my $method_property = $biosample->property('method of derivation')) {
#     my $method_of_derivation = $method_property->values->[0];
#
#     if ($method_of_derivation =~ /cytotune/i) {
#       $sample_index->{'reprogramming'} = {
#         methodOfDerivation => $method_of_derivation,
#         type => 'non-integrating virus',
#         virus => 'sendai',
#       }
#     }
#     elsif ($method_of_derivation =~ /episomal/i) {
#       $sample_index->{'reprogramming'} = {
#         methodOfDerivation => $method_of_derivation,
#         type => 'non-integrating vector',
#         vector => 'episomal',
#       }
#     }
#     elsif ($method_of_derivation =~ /retrovirus/i) {
#       $sample_index->{'reprogramming'} = {
#         methodOfDerivation => $method_of_derivation,
#         type => 'integrating virus',
#         virus => 'retrovirus',
#       }
#     }
#   }
#   if (my $date_property = $biosample->property('date of derivation')) {
#     $sample_index->{'reprogramming'}{'dateOfDerivation'} = $date_property->values->[0];
#   }
#
#   if (my $biomaterial_provider = $biomaterial_provider_hash{$donor->hmdmc}) {
#     $sample_index->{'tissueProvider'} = $biomaterial_provider;
#   }
#   $sample_index->{'openAccess'} = $open_access_hash{$donor->hmdmc};
#
#   my @bankingStatus;
#   if ($is_selected) {
#     if ($osd->is_overridden($sample_index->{name})) {
#       push(@bankingStatus, 'Not selected');
#     }
#     else {
#       push(@bankingStatus, 'Selected for banking');
#     }
#   }
#   elsif (List::Util::any {$_->genomics_selection_status} @{$tissue->ips_lines}) {
#     push(@bankingStatus, 'Not selected');
#   }
#   else {
#     push(@bankingStatus, 'Pending selection');
#   }
#   push(@bankingStatus, 'Shipped to ECACC') if (List::Util::any {$_->type =~ /ecacc/i} @{$ips_line->release}) && exists($sample_index->{'openAccess'});
#   if (my $ecacc_cat_no = $catalog_numbers{$sample_index->{name}}) {
#     $sample_index->{ecaccCatalogNumber} = $ecacc_cat_no;
#     my $html_content = get(sprintf('http://www.phe-culturecollections.org.uk/products/celllines/ipsc/detail.jsp?refId=%s&collection=ecacc_ipsc',
#           $ecacc_cat_no));
#     if ($html_content && $html_content =~ /[\s>]$ecacc_cat_no[\s<]/) {
#       push(@bankingStatus, 'Banked at ECACC');
#     };
#   }
#   if (my $ebisc_name = $ebisc_names{$sample_index->{bioSamplesAccession}}) {
#     $sample_index->{hPSCregName} = $ebisc_name;
#     my $http_response = $ua->get(sprintf('https://cells.ebisc.org/%s', $ebisc_name));
#     if ($http_response->is_success) {
#       push(@bankingStatus, 'Banked at EBiSC');
#       $sample_index->{ebiscName} = $ebisc_name;
#     };
#   }
#   $sample_index->{'bankingStatus'} = \@bankingStatus;
#   $all_samples{$ips_line} = $sample_index;
# }
#
# while( my( $host, $elasticsearchserver ) = each %elasticsearch ){
#   my $cell_created = 0;
#   my $cell_updated = 0;
#   my $cell_uptodate = 0;
#   my $donor_created = 0;
#   my $donor_updated = 0;
#   my $donor_uptodate = 0;
#   CELL_LINE:
#   foreach my $ips_line (@{$cgap_ips_lines}) {
#     my $sample_index = $all_samples{$ips_line};
#     next CELL_LINE if ! $sample_index;
#     my $tissue = $ips_line->tissue;
#     my $donor = $tissue->donor;
#     my $line_exists = $elasticsearchserver->call('exists',
#       index => 'hipsci',
#       type => 'cellLine',
#       id => $sample_index->{name},
#     );
#     if ($line_exists){
#       my $original = $elasticsearchserver->fetch_line_by_name($sample_index->{name});
#       my $update = clone $original;
#       delete $$update{'_source'}{'name'};
#       delete $$update{'_source'}{'bioSamplesAccession'};
#       delete $$update{'_source'}{'donor'}{'name'};
#       delete $$update{'_source'}{'donor'}{'bioSamplesAccession'};
#       if (! scalar keys $$update{'_source'}{'donor'}){
#         delete $$update{'_source'}{'donor'};
#       }
#       delete $$update{'_source'}{'cellType'}{'value'};
#       delete $$update{'_source'}{'cellType'}{'ontologyPURL'};
#       if (! scalar keys $$update{'_source'}{'cellType'}){
#         delete $$update{'_source'}{'cellType'};
#       }
#       delete $$update{'_source'}{'sourceMaterial'};
#       delete $$update{'_source'}{'culture'};
#       delete $$update{'_source'}{'reprogramming'};
#       delete $$update{'_source'}{'tissueProvider'};
#       delete $$update{'_source'}{'openAccess'};
#       delete $$update{'_source'}{'bankingStatus'};
#       delete $$update{'_source'}{'ecaccCatalogNumber'};
#       delete $$update{'_source'}{'ebiscName'};
#       delete $$update{'_source'}{'hPSCregName'};
#       foreach my $field (keys %$sample_index){
#         my $subfield = $$sample_index{$field};
#         if (ref($subfield) eq 'HASH'){
#           foreach my $subfield (keys $$sample_index{$field}){
#             $$update{'_source'}{$field}{$subfield} = $$sample_index{$field}{$subfield};
#           }
#         }else{
#           $$update{'_source'}{$field} = $$sample_index{$field};
#         }
#       }
#       if (Compare($$update{'_source'}, $$original{'_source'})){
#         $cell_uptodate++;
#       }else{
#         $$update{'_source'}{'_indexUpdated'} = $date;
#         $elasticsearchserver->index_line(id => $sample_index->{name}, body => $$update{'_source'});
#         $cell_updated++;
#       }
#     }else{
#       $sample_index->{'_indexCreated'} = $date;
#       $sample_index->{'_indexUpdated'} = $date;
#       $elasticsearchserver->index_line(id => $sample_index->{name}, body => $sample_index);
#       $cell_created++;
#     }
#
#     $donors{$sample_index->{donor}{name}} //= {};
#     my $donor_index = $donors{$sample_index->{donor}{name}};
#     $donor_index->{name} = $sample_index->{donor}{name};
#     $donor_index->{'bioSamplesAccession'} = $donor->biosample_id;
#     #if (!$donor_index->{'cellLines'} || ! grep {$_ eq $sample_index->{'name'}} @{$donor_index->{'cellLines'}}) {
#     #  push(@{$donor_index->{'cellLines'}}, $sample_index->{'name'});
#     #}
#     if (!$donor_index->{'cellLines'} || ! grep {$_->{'name'} eq $sample_index->{'name'}} @{$donor_index->{'cellLines'}}) {
#       push(@{$donor_index->{'cellLines'}}, {name =>$sample_index->{'name'}, bankingStatus => $sample_index->{'bankingStatus'}});
#     }
#     $donor_index->{'tissueProvider'} = $sample_index->{tissueProvider};
#     if (scalar grep {/^Banked/} @{$sample_index->{bankingStatus}}) {
#       $donor_index->{numBankedLines} += 1;
#     }
#   }
#
#   while (my ($donor_name, $donor_index) = each %donors) {
#     my $line_exists = $elasticsearchserver->call('exists',
#       index => 'hipsci',
#       type => 'donor',
#       id => $donor_name,
#     );
#     if ($line_exists){
#       my $original = $elasticsearchserver->fetch_donor_by_name($donor_name);
#       my $update = clone $original;
#       delete $$update{'_source'}{'name'};
#       delete $$update{'_source'}{'bioSamplesAccession'};
#       delete $$update{'_source'}{'cellLines'};
#       delete $$update{'_source'}{'tissueProvider'};
#       delete $$update{'_source'}{'numBankedLines'};
#       foreach my $field (keys %$donor_index){
#         my $subfield = $$donor_index{$field};
#         if (ref($subfield) eq 'HASH'){
#           foreach my $subfield (keys $$donor_index{$field}){
#             $$update{'_source'}{$field}{$subfield} = $$donor_index{$field}{$subfield};
#           }
#         }else{
#           $$update{'_source'}{$field} = $$donor_index{$field};
#         }
#       }
#       if (Compare($$update{'_source'}, $$original{'_source'})){
#         $donor_uptodate++;
#       }else{
#         $$update{'_source'}{'_indexUpdated'} = $date;
#         $elasticsearchserver->index_donor(id => $donor_name, body => $$update{'_source'});
#         $donor_updated++;
#       }
#     }else{
#       $donor_index->{'_indexCreated'} = $date;
#       $donor_index->{'_indexUpdated'} = $date;
#         $elasticsearchserver->index_donor(id => $donor_name, body => $donor_index);
#       $donor_created++;
#     }
#   }
#   print "\n$host\n";
#   print "01_populate_from_cgap\n";
#   print "Cell lines: $cell_created created, $cell_updated updated, $cell_uptodate unchanged.\n";
#   print "Donors: $donor_created created, $donor_updated updated, $donor_uptodate unchanged.\n";
# }
