#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.qc1.pl \
  -es_host=$SERVER \
  -pluritest /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.pluritest.tsv \
  -cnv_file /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.cnv_summary.tsv \
  -cnv_comments_file /nfs/research1/hipsci/drop/hip-drop/tracked/qc1_raw_data/hipsci.qc1.20171220.cnv_comments.tsv