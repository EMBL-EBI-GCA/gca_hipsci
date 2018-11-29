#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ena project id for a sequencing-based study (exome-seq, rna-seq, wgs) comprising raw data.
# Add any new ids to this command line before running this script.

perl $HIPSCI_CODE/scripts/indexes/ena_index.runs.es.pl \
  $ERA_DB_ARGS \
  -study_id ERP006946 \
  -study_id ERP007111 \
  -study_id ERP013436 \
  -study_id ERP017015 \
  -study_id ERP016335 \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
