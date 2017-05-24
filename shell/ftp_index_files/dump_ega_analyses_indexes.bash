#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain current ega dataset ids for sequencing experiments (exomeseq or rna-seq)
# Add any new ids before running this script.
# There will be one output file written per dataset id.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset_id EGAD00001001932 \
  -dataset_id EGAD00001001933 \
  -dataset_id EGAD00001003161 \
  -dataset_id EGAD00001003181 \
  -dataset_id EGAD00001001951 \
  -dataset_id EGAD00001003180 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
