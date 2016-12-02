#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/populate_cell_line.from_cgap_report.pl \
  -es_host=$SERVER \
  -ecacc_index_file $HIPSCI_CODE/tracking_resources/ecacc_catalog_numbers.tsv \
  -hESCreg_user $HESCREG_USER \
  -hESCreg_pass $HESCREG_PASS \
&& perl $HIPSCI_CODE/scripts/elasticsearch/populate_fibroblast_line.from_files_elasticsearch.pl \
  -es_host=$SERVER \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.demographic.pl \
  -es_host=$SERVER \
  -demographic_file /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2016-12-02.csv \
  -sex_sequenome_file /nfs/production/reseq-info/work/streeter/hipsci/resources/sex_sequenome.20160729.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1.pl \
  -es_host=$SERVER \
  -pluritest /nfs/research2/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20161010.pluritest.tsv \
  -cnv /nfs/research2/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20161010.cnv_summary.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1_images.pl \
  -es_host=$SERVER \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.coa.pl \
  -es_host=$SERVER \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.files.pl \
  -es_host=$SERVER \
