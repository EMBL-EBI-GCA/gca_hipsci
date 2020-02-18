#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/populate_fibroblast_line.from_files_elasticsearch.pl \
  -es_host=$SERVER