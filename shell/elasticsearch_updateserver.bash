#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/populate_cell_line.from_cgap_report.pl \
  -es_host=$SERVER \
  -ecacc_index_file $HIPSCI_CODE/tracking_resources/ecacc_catalog_numbers.tsv \
  -hESCreg_user $HESCREG_USER \
  -hESCreg_pass $HESCREG_PASS \
