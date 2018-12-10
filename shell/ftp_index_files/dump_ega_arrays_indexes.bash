#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain dataset ids for array-based experiments (gtarray, mtarray, gexarray)
# Add any new dataset ids before running this script.
# The command line format is: -dataset {DATASET_ID}=/path/to/submission/file.txt
# The submission file is the tab-delimited text file which was sent to EGA to create the dataset.
# There will be one output tsv file written per dataset id.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.pl \
  $ERA_DB_ARGS \
  -dataset EGAD00010001344=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002005.gtarray.201812.tsv \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
#
#  -dataset EGAD00010000773=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.201411.tsv \
#  -dataset EGAD00010000771=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.201504.tsv \
#  -dataset EGAD00010000775=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.201411.tsv \
#  -dataset EGAD00010000777=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001272.gtarray.201411.tsv \
#  -dataset EGAD00010000779=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001273.gtarray.201411.tsv \
#  -dataset EGAD00010000781=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001274.mtarray.201504.tsv \
#  -dataset EGAD00010000817=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001275.mtarray.201504.tsv \
#  -dataset EGAD00010000783=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001276.gexarray.201411.tsv \
#  -dataset EGAD00010000785=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001277.gexarray.201411.tsv \