#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1_images.pl \
  -es_host=$SERVER \
  -trim /nfs/hipsci