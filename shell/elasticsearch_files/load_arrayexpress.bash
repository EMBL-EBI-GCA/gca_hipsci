#!/bin/bash

perl $HIPSCI_CODE/scripts/indexes/arrayexpress_dataset_index.arrays.es.pl \
  -dataset_id E-MTAB-4057 \
  -dataset_id E-MTAB-4059 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
