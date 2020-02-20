#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.predicted_populations.pl \
  -es_host=$SERVER \
  --predicted_population_filename=/nfs/research1/hipsci/drop/hip-drop/tracked/predicted_population/hipsci.pca_557.20170928.predicted_populations.tsv

