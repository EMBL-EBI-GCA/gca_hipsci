#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/populate_cell_line.from_cgap_report.pl \
  -es_host=$SERVER \
  -ecacc_index_file $HIPSCI_CODE/tracking_resources/ecacc_catalog_numbers.tsv \
  -hESCreg_user $HESCREG_USER \
  -hESCreg_pass $HESCREG_PASS \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.demographic.pl \
  -es_host=$SERVER \
  -demographic_file /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv \
  -sex_sequenome_file /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/sex_sequenome.20160729.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1.pl \
  -es_host=$SERVER \
  -pluritest /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.pluritest.tsv \
  -cnv_file /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.cnv_summary.tsv \
  -cnv_comments_file /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.cnv_comments.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1_images.pl \
  -es_host=$SERVER \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.coa.pl \
  -es_host=$SERVER \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.differentiations.pl \
  -es_host=$SERVER \
  --yaml=$HIPSCI_CODE/tracking_resources/differentiations/macrophage_2016.yaml \
  --yaml=$HIPSCI_CODE/tracking_resources/differentiations/sensory_neurons_2016.yaml \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.predicted_populations.pl \
  -es_host=$SERVER \
  --predicted_population_filename=/nfs/research1/hipsci/drop/hip-drop/tracked/predicted_population/hipsci.pca_557.20170928.predicted_populations.tsv
