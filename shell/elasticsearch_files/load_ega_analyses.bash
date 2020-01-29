#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ega dataset id for sequencing experiments (exomeseq or rna-seq)
# Remove old dataset ids from this command line, and add any new ones before running this script.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.es.pl \
  $ERA_DB_ARGS \
  -dataset_id EGAD00010001344 \
  -dataset_id EGAD00010001346 \
  -dataset_id EGAD00010001348 \
  -dataset_id EGAD00010001350 \
  -dataset_id EGAD00010001352 \
  -dataset_id EGAD00010001354 \
  -dataset_id EGAD00010001356 \
  -dataset_id EGAD00010001358 \
  -dataset_id EGAD00010001360 \
  -dataset_id EGAD00010001362 \
  -dataset_id EGAD00010001364 \
  -dataset_id EGAD00010001366 \
  -dataset_id EGAD00010001368 \
  -dataset_id EGAD00010001370 \
  -dataset_id EGAD00010001372 \
  -dataset_id EGAD00010001374 \
  -dataset_id EGAD00010001376 \
  -dataset_id EGAD00010001378 \
  -dataset_id EGAD00010001380 \
  -dataset_id EGAD00010001382 \
  -dataset_id EGAD00010001384 \
  -dataset_id EGAD00010001386 \
  -dataset_id EGAD00010001388 \
  -dataset_id EGAD00010001390 \
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
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv



#  -dataset_id EGAD00001001999 \
#  -dataset_id EGAD00001002000 \
#  -dataset_id EGAD00001000893 \
#  -dataset_id EGAD00001000897 \
#  -dataset_id EGAD00001001422 \
#  -dataset_id EGAD00001001437 \
#  -dataset_id EGAD00001001438 \
#  -dataset_id EGAD00001001932 \
#  -dataset_id EGAD00001001933 \
#  -dataset_id EGAD00001001949 \
#  -dataset_id EGAD00001001950 \
#  -dataset_id EGAD00001001951 \
#  -dataset_id EGAD00001001952 \
#  -dataset_id EGAD00001001953 \
#  -dataset_id EGAD00001001954 \
#  -dataset_id EGAD00001001955 \
#  -dataset_id EGAD00001003161 \
#  -dataset_id EGAD00001003180 \
#  -dataset_id EGAD00001003181 \
#  -dataset_id EGAD00001003516 \
#  -dataset_id EGAD00001003517 \
#  -dataset_id EGAD00001003518 \
#  -dataset_id EGAD00001003519 \
#  -dataset_id EGAD00001003520 \
#  -dataset_id EGAD00001003521 \
#  -dataset_id EGAD00001003522 \
#  -dataset_id EGAD00001003523 \
#  -dataset_id EGAD00001003524 \
#  -dataset_id EGAD00001003525 \
#  -dataset_id EGAD00001003526 \
#  -dataset_id EGAD00001003527 \
#  -dataset_id EGAD00001003528 \
#  -dataset_id EGAD00001003529 \
#  -dataset_id EGAD00001003530 \
#  -dataset_id EGAD00001003531 \
#  -dataset_id EGAD00001003532 \
#  -dataset_id EGAD00001003533 \
#  -dataset_id EGAD00001003534 \
#  -dataset_id EGAD00001003535 \
#  -dataset_id EGAD00001003536 \
#  -dataset_id EGAD00001003537 \
#  -dataset_id EGAD00001003538 \
#  -dataset_id EGAD00001003539 \
#  -dataset_id EGAD00001003540 \
#  -dataset_id EGAD00001003541 \
#  -dataset_id EGAD00001003542 \
#  -dataset_id EGAD00001003543 \


