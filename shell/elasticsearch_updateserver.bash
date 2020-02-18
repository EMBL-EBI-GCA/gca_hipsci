#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.demographic.pl \
  -es_host=$SERVER \
  -demographic_file /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv \
  -sex_sequenome_file /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/sex_sequenome.20160729.tsv
