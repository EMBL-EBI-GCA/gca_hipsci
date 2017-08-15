#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain current ega dataset ids for sequencing experiments (exomeseq or rna-seq)
# Add any new ids before running this script.
# There will be one output file written per dataset id.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset_id EGAD00001003161 \
  -dataset_id EGAD00001003514 \
  -dataset_id EGAD00001003515 \
  -dataset_id EGAD00001003516 \
  -dataset_id EGAD00001003517 \
  -dataset_id EGAD00001003518 \
  -dataset_id EGAD00001003519 \
  -dataset_id EGAD00001003520 \
  -dataset_id EGAD00001003521 \
  -dataset_id EGAD00001003522 \
  -dataset_id EGAD00001003523 \
  -dataset_id EGAD00001003524 \
  -dataset_id EGAD00001003525 \
  -dataset_id EGAD00001003526 \
  -dataset_id EGAD00001003527 \
  -dataset_id EGAD00001003528 \
  -dataset_id EGAD00001003529 \
  -dataset_id EGAD00001003530 \
  -dataset_id EGAD00001003531 \
  -dataset_id EGAD00001003532 \
  -dataset_id EGAD00001003533 \
  -dataset_id EGAD00001003534 \
  -dataset_id EGAD00001003535 \
  -dataset_id EGAD00001003536 \
  -dataset_id EGAD00001003537 \
  -dataset_id EGAD00001003538 \
  -dataset_id EGAD00001003539 \
  -dataset_id EGAD00001003540 \
  -dataset_id EGAD00001003541 \
  -dataset_id EGAD00001003542 \
  -dataset_id EGAD00001003543 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
