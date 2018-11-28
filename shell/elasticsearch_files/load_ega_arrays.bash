#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ega dataset id for array-based experiments (gtarray, mtarray, gexarray)
# Remove old dataset ids from this command line, and add any new ones before running this script.
# The command line format is: -dataset {DATASET_ID}=/path/to/submission/file.txt
# The submission file is the tab-delimited text file which was sent to EGA to create the dataset.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.es.pl \
  $ERA_DB_ARGS \
  -dataset EGAD00010001147=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.20161212.txt \
  -dataset EGAD00010001139=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.20161212.txt \
  -dataset EGAD00010001143=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.20161212.txt \
  -dataset EGAD00010000777=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001272.gtarray.201411.tsv \
  -dataset EGAD00010000779=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001273.gtarray.201411.tsv \
  -dataset EGAD00010001145=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001274.mtarray.20161212.txt \
  -dataset EGAD00010001149=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001275.mtarray.20161212.txt \
  -dataset EGAD00010000783=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001276.gexarray.201411.tsv \
  -dataset EGAD00010000785=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001277.gexarray.201411.tsv \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
