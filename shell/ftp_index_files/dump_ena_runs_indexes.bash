#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain ena project ids for sequencing-based studies (exome-seq, rna-seq, wgs) comprising raw data.
# Add any new ids to this command line before running this script.
# There will be one output file written per study id

perl $HIPSCI_CODE/scripts/indexes/ena_index.runs.pl \
  -era_password $RESEQTRACK_PASS \
  -study_id ERP006946 \
  -study_id ERP007111 \
  -study_id ERP013436 \
  -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
