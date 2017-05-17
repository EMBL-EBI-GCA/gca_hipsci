#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.es.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset_id EGAD00001001932 \
  -dataset_id EGAD00001001933 \
  -dataset_id EGAD00001003161 \
  -dataset_id EGAD00001003181 \
  -dataset_id EGAD00001001951 \
  -dataset_id EGAD00001003180 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
