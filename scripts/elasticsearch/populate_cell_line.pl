#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use Getopt::Long;
use BioSD;
use Search::Elasticsearch;

#This is temporary whilst I am tunnelling into Elasticsearch
#use Net::OpenSSH;

# start with this sql statement, create index for biosamples which match this:
# select sa.biosample_id from sample sa, run r, run_sample rs, experiment e, study st
# where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id and e.study_id=st.study_id
# and st.ega_id='EGAS00001000593' group by sa.biosample_id order by sa.biosample_id;

#my @feeder_free_temp_override = (
  #qw(leeh_3 iakz_1 febc_2 nibo_3 aehn_2 oarz_22 zisa_33 peop_4 dard_2 coxy_33 xisg_33 oomz_22 dovq_33 liun_22 xavk_33 aehn_22 funy_1 funy_3 giuf_1 giuf_3 iill_1 iill_3 bima_1 bima_2 ieki_2 ieki_3 qolg_1 qolg_3 bulb_1 gusc_1 gusc_2 gusc_3)
#);

my $demographic_filename;
my $growing_conditions_filename;
my $cnv_filename;
my $pluritest_filename;
my %study_ids;
my @era_params = ('ops$laura', undef, 'ERAPRO');
my $es_host='vg-rs-dev1:9200';

#This is temporary whilst I am tunnelling into Elasticsearch
#my $ssh_password;
#my $ssh_user = 'streeter';
#my $ssh_host = 'streeter.windows.ebi.ac.uk';
#my $ssh_config_file = '/homes/streeter/.ssh/config';
#my $ssh_known_hosts_file = '/homes/streeter/.ssh/known_hosts';
##

&GetOptions(
  'demographic_file=s' => \$demographic_filename,
  'growing_conditions_file=s' => \$growing_conditions_filename,
  'pluritest_file=s' => \$pluritest_filename,
  'cnv_filename=s' => \$cnv_filename,
  'era_password=s'              => \$era_params[1],
          #'ssh_user=s' => \$ssh_user,
          #'ssh_host=s' => \$ssh_host,
          #'ssh_password=s' => \$ssh_password,
          #'ssh_config_file=s' => \$ssh_config_file,
          #'ssh_known_hosts_file=s' => \$ssh_known_hosts_file,
          'rnaseq=s' =>\&study_id_handler,
          'chipseq=s' =>\&study_id_handler,
          'exomeseq=s' =>\&study_id_handler,
          'es_host=s' =>\&es_host,
);

sub study_id_handler {
  my ($assay_name, $study_id) = @_;
  push(@{$study_ids{$assay_name}}, $study_id);
}

die "did not get a demographic file on the command line" if !$demographic_filename;

my $sql =  '
  select sa.biosample_id from sample sa, run r, run_sample rs, experiment e, study st
  where sa.sample_id=rs.sample_id and rs.run_id=r.run_id and r.experiment_id=e.experiment_id and e.study_id=st.study_id
  and st.ega_id=? group by sa.biosample_id
  ';

my %sample_details;
my $era_db = get_erapro_conn(@era_params);
my $sth = $era_db->dbc->prepare($sql) or die "could not prepare $sql";
while (my ($assay, $study_ids) = each %study_ids) {
  foreach my $study_id (@$study_ids) {
    $sth->bind_param(1, $study_id);
    $sth->execute or die "could not execute";
    while (my $row = $sth->fetchrow_arrayref) {
      $sample_details{$row->[0]}{assays}{$assay} = $study_id;
    }
  }
}

#This is temporary whilst I am tunnelling into Elasticsearch
#my $ssh = Net::OpenSSH->new($ssh_host, user => $ssh_user, password=>$ssh_password,
    #master_opts => [-F => $ssh_config_file, -o => "UserKnownHostsFile $ssh_known_hosts_file"]
#);

my $elasticsearch = Search::Elasticsearch->new(nodes => $es_host);

my %cnv_details;
open my $cnv_fh, '<', $cnv_filename or die "could not open $cnv_filename $!";
<$cnv_fh>;
while (my $line = <$cnv_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $cnv_details{$split_line[0]} = \@split_line;
}
close $cnv_fh;

my %pluritest_details;
open my $pluri_fh, '<', $pluritest_filename or die "could not open $pluritest_filename $!";
<$pluri_fh>;
while (my $line = <$pluri_fh>) {
  chomp $line;
  my @split_line = split("\t", $line);
  $pluritest_details{$split_line[0]} = \@split_line;
}
close $pluri_fh;

my %donors;

SAMPLE:
while (my ($biosample_id, $sample_index) = each %sample_details) {
  my $biosample = BioSD::fetch_sample($biosample_id);
  my $cell_type = $biosample->property('cell type')->values->[0];
  next SAMPLE if $cell_type ne 'induced pluripotent stem cell';
  my $derived_from = $biosample->derived_from->[0];
  my $donor = $derived_from->derived_from->[0];

  my $source_material = $derived_from->property('cell type')->values->[0];
  $source_material = $source_material eq 'pbmc' ? 'PBMC'
                  : $source_material eq 'fibroblast' ? 'Fibroblast'
                  : $source_material;

  my $disease = $derived_from->property('disease state')->values->[0];
  $disease = $disease eq 'normal' ? 'Normal'
                  : $disease =~ /bardet/i ? 'Bardet-Biedl syndrome'
                  : $disease =~ /neonatal diabetes/i ? 'Neonatal Diabetes'
                  : $disease;

  my $growing_conditions = $biosample->property('growing conditions')->values->[0];
  my $growing_conditions_qc1 = $growing_conditions =~ /feeder/i ? 'Feeder dependent' : 'E8 media';
  my $growing_conditions_qc2 = $growing_conditions =~ /E8 media/i ? 'E8 media' : 'Feeder dependent';

  $sample_index->{name} = $biosample->property('Sample Name')->values->[0];
  $sample_index->{'cellType'} = $cell_type;
  $sample_index->{'bioSamplesAccession'} = $biosample_id;
  $sample_index->{'diseaseStatus'} = $disease;
  $sample_index->{'sourceMaterial'} = $source_material;
  $sample_index->{'tissueProvider'} = $donor->property('biomaterial provider')->values->[0];
  $sample_index->{'growingConditionsQC1'} = $growing_conditions_qc1;
  $sample_index->{'growingConditionsQC2'} = $growing_conditions_qc2;
  $sample_index->{'dateOfDerivation'} = $biosample->property('date of derivation')->values->[0];
  $sample_index->{'donor'} = $donor->property('Sample Name')->values->[0];
  if (my $ethnicity_property = $biosample->property('ethnicity')) {
    $sample_index->{'donorEthnicity'} = $ethnicity_property->values->[0];
  }
  if (my $age_property = $biosample->property('age')) {
    $sample_index->{'donorAge'} = $age_property->values->[0];
  }
  if (my $sex_property = $biosample->property('Sex')) {
    $sample_index->{'sex'} = $sex_property->values->[0];
  }

  my $cnv_details = $cnv_details{$sample_index->{name}};
  $sample_index->{cnv_num_different_regions} = $cnv_details->[1];
  $sample_index->{cnv_length_different_regions_Mbp} = $cnv_details->[2];
  $sample_index->{cnv_length_shared_differences_Mbp} = $cnv_details->[3];

  my $pluri_details = $pluritest_details{$sample_index->{name}};
  $sample_index->{pluri_raw} = $pluri_details->[1];
  $sample_index->{pluri_logit_p} = $pluri_details->[2];
  $sample_index->{pluri_novelty} = $pluri_details->[3];
  $sample_index->{pluri_novelty_logit_p} = $pluri_details->[4];
  $sample_index->{pluri_rmsd} = $pluri_details->[5];

  $elasticsearch->index(
    index => 'hipsci',
    type => 'cellLine',
    id => $sample_index->{name},
    body => $sample_index,
    );

  $donors{$sample_index->{donor}} //= {};
  my $donor_index = $donors{$sample_index->{donor}};
  $donor_index->{name} = $sample_index->{donor};
  $donor_index->{'bioSamplesAccession'} = $donor->id;
  $donor_index->{'diseaseStatus'} = $disease;
  $donor_index->{'sex'} = $sample_index->{sex};
  $donor_index->{'ethnicity'} = $sample_index->{'donorEthnicity'};
  $donor_index->{'age'} = $sample_index->{'donorAge'};
  push(@{$donor_index->{'cellLines'}}, $sample_index->{'name'});
  
}
while (my ($donor_name, $donor_index) = each %donors) {
  $elasticsearch->index(
    index => 'hipsci',
    type => 'donor',
    id => $donor_name,
    body => $donor_index,
    );
}
