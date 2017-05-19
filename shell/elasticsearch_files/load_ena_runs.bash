#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

perl $HIPSCI_CODE/scripts/indexes/ena_index.runs.es.pl \
  -era_password $RESEQTRACK_PASS \
  -study_id ERP006946 \
  -study_id ERP007111 \
  -study_id ERP013436 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
