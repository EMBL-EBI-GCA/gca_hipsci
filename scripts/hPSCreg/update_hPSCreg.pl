#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover qw(improve_donors);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use ReseqTrack::EBiSC::hESCreg;
use Getopt::Long;
use BioSD;
use Search::Elasticsearch;
use List::Util qw();
use JSON qw(encode_json);
use POSIX qw(strftime);

my ($hESCreg_user, $hESCreg_pass);
my $demographic_filename;
my $es_host='vg-rs-dev1:9200';
my @era_params = ('ops$laura', undef, 'ERAPRO');
my $final_submit = 0;

GetOptions("hESCreg_user=s" => \$hESCreg_user,
    "hESCreg_pass=s" => \$hESCreg_pass,
    'demographic_file=s' => \$demographic_filename,
    'es_host=s' =>\$es_host,
    'era_password=s'    => \$era_params[1],
    'final_submit'    => \$final_submit,
);
die "missing credentials" if !$hESCreg_user || !$hESCreg_pass;

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
);

my $era_db = get_erapro_conn(@era_params);
my $sql_ena =  '
  select a.analysis_id, a.analysis_title from analysis_sample ans, sample s, analysis a
  where ans.sample_id=s.sample_id and a.analysis_id=ans.analysis_id
  and s.biosample_id=?
  ';
my $sth_ena = $era_db->dbc->prepare($sql_ena) or die "could not prepare $sql_ena";


my $hESCreg = ReseqTrack::EBiSC::hESCreg->new(
  user => $hESCreg_user,
  pass => $hESCreg_pass,
  #host => 'test.hescreg.eu',
  #realm => 'hESCreg Development'
);
my ($cgap_ips_lines, $cgap_donors) =  @{read_cgap_report()}{qw(ips_lines donors)};
improve_donors(donors=>$cgap_donors, demographic_file=>$demographic_filename);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);
my $es_scroll = $elasticsearch->scroll_helper(
  index => 'hescreg',
  search_type => 'scan',
  type => 'line',
  body => {
    query => {
      filtered => {
        filter => {
          term => {
            'providers.id' => 437,
          }
        }
      }
    }
  }
);

LINE:
while (my $es_doc = $es_scroll->next) {
  my $line = $es_doc->{_source};
  my $ebisc_name = $line->{name};
  next LINE if $ebisc_name !~ /^WTSI/;
  my $cgap_line = List::Util::first {$_->biosample_id && $line->{biosamples_id} && $_->biosample_id eq $line->{biosamples_id}}  @{$cgap_ips_lines};
  next LINE if !$cgap_line;
  my $hipsci_name = $cgap_line->name;


  my $biosample = BioSD::fetch_sample($cgap_line->biosample_id);
  my $method_property = $biosample->property('method of derivation');
  die "no method property for $hipsci_name" if !$method_property;

#  if (!$open_access_hash{$cgap_line->tissue->donor->hmdmc}) {
#    print STDERR "$ebisc_name $hipsci_name: this script is set up only for open access lines\n";
#    next LINE;
#  }

  my $tissue_biosample = BioSD::fetch_sample($cgap_line->tissue->biosample_id);
  my $donor_biosample = BioSD::fetch_sample($cgap_line->tissue->donor->biosample_id);

  my $post_hash = $hESCreg->blank_post_hash();
  $post_hash->{biosamples_id} = $biosample->id;
  $post_hash->{biosamples_donor_id} = $donor_biosample->id;
  $post_hash->{form_finished_flag} .= 1;
  $post_hash->{migration_status} .= 1;
  $post_hash->{final_name_generated_flag} .= 1;
  $post_hash->{final_submit_flag} .= $final_submit ? 1 : 0;
  $post_hash->{id} .= $line->{id};
  $post_hash->{validation_status} .= 3;
  $post_hash->{name} = $ebisc_name;
  push(@{$post_hash->{alternate_name}}, $hipsci_name);
  $post_hash->{type} .= 1;
  $post_hash->{donor_number} = $ebisc_name =~ /WTSIi(\d+)/ ? $1 +0 : die "no donor number for $ebisc_name";
  $post_hash->{donor_cellline_number} .= $ebisc_name =~ /-([A-Z]+)/ ? ord($1) - 64 : die "no donor cellline number for $ebisc_name";
  $post_hash->{donor_cellline_subclone_number} .= 0;
  $post_hash->{internal_donor_id} = $donor_biosample->property('Sample Name')->values->[0];
  push(@{$post_hash->{internal_donor_ids}}, $post_hash->{internal_donor_id});
  $post_hash->{available_flag} .= 1;
  $post_hash->{availability_restrictions} = 'with_restrictions';
  $post_hash->{same_donor_cell_line_flag} = $line->{same_donor_cell_line_flag};
  $post_hash->{same_donor_derived_from_flag} = $line->{same_donor_derived_from_flag};
  $post_hash->{provider_generator} .= 437;
  $post_hash->{provider_owner} .= 437;
  #$post_hash->{source_platform} = $line->{source_platform} || '';
  $post_hash->{source_platform} = 'ebisc';
  $post_hash->{genetic_information_associated_flag} .= 1;
  $post_hash->{genetic_information_available_flag} .= 1;
  if ($method_property->values->[0] =~ /cytotune/i) {
    $post_hash->{vector_type} = 'non_integrating';
    $post_hash->{non_integrating_vector} = 'sendai_virus';
    $post_hash->{hips_recombined_dna_vectors_supplier} = 'Lifetech';
    push(@{$post_hash->{non_integrating_vector_gene_list}}, 
      'ENSG00000204531###POU5F1###ensembl_id###id_type_gene',
      'ENSG00000181449###SOX2###ensembl_id###id_type_gene',
      'ENSG00000136826###KLF4###ensembl_id###id_type_gene',
      'ENSG00000136997###MYC###ensembl_id###id_type_gene',
    );
  }
  elsif ($method_property->values->[0] =~ /episomal/i) {
    $post_hash->{vector_type} = 'non_integrating';
    $post_hash->{non_integrating_vector} = 'episomal';
    push(@{$post_hash->{non_integrating_vector_gene_list}}, 
      'ENSG00000204531###POU5F1###ensembl_id###id_type_gene',
      'ENSG00000181449###SOX2###ensembl_id###id_type_gene',
      'ENSG00000136826###KLF4###ensembl_id###id_type_gene',
      'ENSG00000136997###MYC###ensembl_id###id_type_gene',
      'ENSG00000131914###LIN28###ensembl_id###id_type_gene',
      'ENSG00000111704###NANOG###ensembl_id###id_type_gene',
    );
  }
  elsif ($method_property->values->[0] =~ /retrovirus/i) {
    $post_hash->{vector_type} = 'integrating';
    $post_hash->{integrating_vector} = 'virus';
    $post_hash->{integrating_vector_virus_type} = 'retrovirus';
    push(@{$post_hash->{integrating_vector_gene_list}}, 
      'ENSG00000204531###POU5F1###ensembl_id###id_type_gene',
      'ENSG00000181449###SOX2###ensembl_id###id_type_gene',
      'ENSG00000136826###KLF4###ensembl_id###id_type_gene',
      'ENSG00000136997###MYC###ensembl_id###id_type_gene',
    );
  }
  $post_hash->{excisable_vector_flag} .= 0;
  $post_hash->{dev_stage_primary_cell} = 'adult';
  if (my $age = $cgap_line->tissue->donor->age) {
    $post_hash->{donor_age} = $age;
  }
  $post_hash->{gender_primary_cell} = $cgap_line->tissue->donor->gender || "";
  if (my $disease = $cgap_line->tissue->donor->disease) {
    if ($disease =~ /normal/i) {
      $post_hash->{disease_flag} .= 0;
      push(@{$post_hash->{disease_associated_phenotypes}}, 'normal');
    }
    elsif ($disease =~ /bardet/i) {
      $post_hash->{disease_flag} .= 1;
      $post_hash->{disease_doid} .= 'http://www.orpha.net/ORDO/Orphanet_110';
      $post_hash->{disease_doid_name} .= 'Bardet-Biedl syndrome';
    }
    else {
      $post_hash->{disease_flag} .= 1;
    }
  }
  if (my $cell_type_property = $tissue_biosample->property('cell type')) {
    my $cell_type_qual_val = $cell_type_property->qualified_values()->[0];
    my $cell_type_purl = $cell_type_qual_val->term_source()->term_source_id();
    if ($cell_type_purl !~ /^http:/) {
      $cell_type_purl = $cell_type_qual_val->term_source()->uri() . '/' . $cell_type_purl;
    }
    $post_hash->{primary_celltype_ont_id} = $cell_type_purl;
    $post_hash->{primary_celltype_name} = $cell_type_qual_val->value();
    if ($cell_type_property->values->[0] =~ /fibroblast/i) {
      $post_hash->{location_primary_tissue_procurement} = 'arm';
      $post_hash->{primary_celltype_ont_id} = 'http://purl.obolibrary.org/obo/CL_0002551';
      $post_hash->{primary_celltype_name} = 'fibroblast of dermis';
      $post_hash->{primary_celltype_name_freetext} = 'Dermal Fibroblast';
    }
  }
  $post_hash->{selection_of_clones} = 'Morphology';
  $post_hash->{derivation_gmp_ips_flag} .= 0;
  $post_hash->{available_clinical_grade_ips_flag} .= 0;
  $post_hash->{derivation_xeno_graft_free_flag} .= 0;

  if (my $bank_release = (List::Util::first {$_->type =~ /ebisc/i} @{$cgap_line->release})
        || (List::Util::first {$_->type =~ /ecacc/i} @{$cgap_line->release})
        || $cgap_line->get_release_for(type => 'qc2', date => strftime('%Y%m%d', localtime)) ) {
    if ($bank_release->is_feeder_free) {
      $post_hash->{surface_coating} = 'vitronectin';
      $post_hash->{feeder_cells_flag} .= 0;
      $post_hash->{passage_method} = 'enzyme_free';
      $post_hash->{passage_method_enzyme_free} = 'edta';
      $post_hash->{culture_conditions_medium_culture_medium} = 'tesr_e8';
    }
    else {
      $post_hash->{surface_coating} = 'gelatine';
      $post_hash->{feeder_cells_flag} .= 1;
      $post_hash->{feeder_cells_name} = 'Mouse embryonic fibroblasts';
      $post_hash->{feeder_cells_ont_id} = 'EFO0004040';
      $post_hash->{passage_method_enzymatic} = 'other';
      $post_hash->{passage_method_enzymatic_other} = 'collagenase and dispase';
    }
  }
  $post_hash->{co2_concentration} .= 5;
  $post_hash->{certificate_of_analysis_flag} .= 0;
  push(@{$post_hash->{undiff_immstain_marker}}, 
    'ENSG00000204531###%2B###POU5F1###ensembl_id###id_type_gene',
    'ENSG00000181449###%2B###Sox2###ensembl_id###id_type_gene',
    'ENSG00000111704###%2B###NANOG###ensembl_id###id_type_gene',
  );
  $post_hash->{virology_screening_flag} .= 0;
  $post_hash->{karyotyping_flag} .= 0;
  $post_hash->{hla_flag} .= 0;
  $post_hash->{fingerprinting_flag} .= 0;
  $post_hash->{genetic_modification_flag} .= 0;
  $post_hash->{derivation_country} = 'GB';
  $post_hash->{data_accurate_and_complete_flag} .= $final_submit ? 1 : 0;
  $post_hash->{ethnicity} = $cgap_line->tissue->donor->ethnicity;
  if ($line->{comparator_cell_line_id}) {
    $post_hash->{comparator_cell_line_id} = $line->{comparator_cell_line_id};
    $post_hash->{comparator_cell_line_type} = $line->{comparator_cell_line_type} || 'comparator_no';
  }
  else {
    $post_hash->{comparator_cell_line_type} = 'comparator_no';
    delete $post_hash->{comparator_cell_line_id};
  }
  $post_hash->{other_culture_environment} = 'Temperature 37C';
  $post_hash->{genome_wide_genotyping_flag} .= 1;
  $post_hash->{genome_wide_genotyping_ega} = 'exomeseq';

  my %exome_seq_study = (
    'H1288' => 'EGAS00001000592',
    '13_058' => 'EGAS00001000969',
    '14_001' => 'EGAS00001000969',
    '14_025' => 'EGAS00001001140',
  );

  if ($open_access_hash{$cgap_line->tissue->donor->hmdmc}) {
    $sth_ena->bind_param(1, 'SAMEA2547633');
    $sth_ena->execute or die "could not execute";
    ROW:
    while (my $row = $sth_ena->fetchrow_arrayref) {
      if ($row->[1] =~ /imputed.*vcf/) {
        $post_hash->{genome_wide_genotyping_ega_url} = sprintf('http://www.ebi.ac.uk/ena/data/view/%s', $row->[0]);
        last ROW;
      }
    }
  }
  else {
    $post_hash->{genome_wide_genotyping_ega_url} = sprintf('https://www.ebi.ac.uk/ega/studies/%s', $exome_seq_study{$cgap_line->tissue->donor->hmdmc});
  }
  $post_hash->{hips_genetic_information_access_policy} = $open_access_hash{$cgap_line->tissue->donor->hmdmc} ? 'open_access' : 'controlled_access';



##ethics:
  if ($open_access_hash{$cgap_line->tissue->donor->hmdmc}
    || $cgap_line->tissue->donor->hmdmc eq 'H1288') {
    $post_hash->{hips_consent_obtained_from_donor_of_tissue_flag} .= 1;
    $post_hash->{hips_no_pressure_stat_flag} .= 1;
    $post_hash->{hips_no_inducement_stat_flag} .= 1;
    $post_hash->{hips_informed_consent_flag} .= 0;
    $post_hash->{hips_provide_copy_of_donor_consent_information_english_flag} .= 1;
    $post_hash->{hips_provide_copy_of_donor_consent_english_flag} .= 1;
    $post_hash->{hips_consent_permits_ips_derivation_flag} .= 1;
    $post_hash->{hips_consent_pertains_specific_research_project_flag} .= 0;
    $post_hash->{hips_consent_permits_future_research_flag} .= 1;
    $post_hash->{hips_consent_permits_clinical_treatment_flag} .= 0;
    $post_hash->{hips_formal_permission_for_distribution_flag} .= 1;
    $post_hash->{hips_consent_permits_research_by_academic_institution_flag} .= 1;
    $post_hash->{hips_consent_permits_research_by_for_profit_company_flag} .= 1;
    $post_hash->{hips_consent_permits_research_by_non_profit_company_flag} .= 1;
    $post_hash->{hips_consent_permits_research_by_public_org_flag} .= 1;
    $post_hash->{hips_consent_expressly_prevents_commercial_development_flag} .= 0;
    $post_hash->{hips_further_constraints_on_use_flag} .= 0;
    $post_hash->{hips_consent_expressly_permits_indefinite_storage_flag} .= 1;
    $post_hash->{hips_consent_prevents_availiability_to_worldwide_research_flag} .= 0;
    $post_hash->{hips_derived_information_influence_personal_future_treatment_flag} .= 0;
    $post_hash->{hips_donor_data_protection_informed_flag} .= 1;
    $post_hash->{hips_donated_material_code_flag} .= 1;
    $post_hash->{hips_donated_material_rendered_unidentifiable_flag} .= 0;
    $post_hash->{hips_donor_identity_protected_rare_disease_flag} .= 1;
    $post_hash->{hips_approval_flag} .= 1;
    $post_hash->{hips_approval_auth_name} .= 'NRES Committee Yorkshire & The Humber - Leeds West';
    $post_hash->{hips_approval_number} .= '15/YH/0391';
    $post_hash->{hips_ethics_review_panel_opinion_project_proposed_use_flag} = 1;
    $post_hash->{hips_third_party_obligations_flag} .= 0;
    $post_hash->{hips_holding_original_donor_consent_copy_of_existing_flag} .= 1;
    $post_hash->{hips_holding_original_donor_consent_flag} .= 1;
    $post_hash->{hips_arrange_obtain_new_consent_form_flag} .= 0;
    $post_hash->{hips_donor_recontact_agreement_flag} .= 0;
    $post_hash->{hips_consent_expressly_prevents_financial_gain_flag} .= 0;
    $post_hash->{hips_consent_permits_access_medical_records_flag} .= 1;
    $post_hash->{hips_consent_permits_access_other_clinical_source_flag} .= 0;
    $post_hash->{usage_approval_flag} = ['research_only'];
    $post_hash->{hips_consent_permits_stop_of_derived_material_use_flag} .= 0;
    $post_hash->{hips_consent_permits_delivery_of_information_and_data_flag} .= 0;
    $post_hash->{hips_consent_permits_genetic_testing_flag} .= 1;
    $post_hash->{hips_consent_permits_testing_microbiological_agents_pathogens_flag} .= 1;
    $post_hash->{hips_future_research_permitted_specified_areas_flag} .= 0;
    $post_hash->{hips_consent_permits_development_of_commercial_products_flag} .= 1;
  }

=cut 

  # not part of the EBiSC form
  $post_hash->{hips_use_or_distribution_constraints_flag} .= 1;
  $post_hash->{hips_use_or_distribution_constraints} = 'can only be used for academic reserach not commercial';
  $post_hash->{material_transfer_agreement_flag} .= 1;

=cut
  
  #print encode_json($post_hash), "\n"; exit;
  #use Data::Dumper; print Dumper $post_hash; exit;
  my $response =  $hESCreg->post_line($post_hash);
  if ($response =~ /error/i) {
    print $response;
    print encode_json($post_hash), "\n";
    exit;
  }
  print $ebisc_name, "\n";
  print $response, "\n";
  sleep(1);
}
