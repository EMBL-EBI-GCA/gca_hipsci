#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain arrayexpress ids for array-based experiments (mtarray or gexarray)
# Add any new ids before running this script.
# There will be one output file written per dataset_id

perl $HIPSCI_CODE/scripts/indexes/arrayexpress_dataset_index.arrays.pl \
  -dataset_id E-MTAB-4057 \
  -dataset_id E-MTAB-4059 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
