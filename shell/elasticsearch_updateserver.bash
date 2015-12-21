#!/bin/bash

SERVER1=$1
SERVER2=$2

perl $HIPSCI_CODE/scripts/elasticsearch/populate_cell_line.from_cgap_report.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
&& perl $HIPSCI_CODE/scripts/elasticsearch/populate_fibroblast_line.from_files_elasticsearch.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.demographic.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -demographic_file /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-12-16.csv \
&& source /nfs/production/reseq-info/work/hipdcc/oracle_env_hinxton.sh \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -pluritest /nfs/research2/hipsci/drop/hip-drop/incoming/keane/hipsci_data/hipsci.qc1.pluritest.tsv \
  -cnv /nfs/research2/hipsci/drop/hip-drop/incoming/keane/hipsci_data/hipsci.qc1.cnv_summary.tsv \
  -allowed_samples_gtarray /nfs/research2/hipsci/tracking_resources/qc_samples/allowed_samples.gtarray.tsv \
  -allowed_samples_gexarray /nfs/research2/hipsci/tracking_resources/qc_samples/allowed_samples.gexarray.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1_images.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.ebisc_names.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -hESCreg_user $HESCREG_USER \
  -hESCreg_pass $HESCREG_PASS \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.coa.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -trim /nfs/hipsci \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.ecacc_cat_no.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200 \
  -ecacc_index_file $HIPSCI_CODE/tracking_resources/ecacc_catalog_numbers.tsv \
&& perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.files.pl \
  -es_host=$SERVER1:9200 -es_host=$SERVER2:9200
