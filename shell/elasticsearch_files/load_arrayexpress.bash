#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current arrayexpress id for an array-based experiment (mtarray or gexarray)
# Add any new ids before running this script.

perl $HIPSCI_CODE/scripts/indexes/arrayexpress_dataset_index.arrays.es.pl \
  -dataset_id E-MTAB-4057 \
  -dataset_id E-MTAB-4059 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
