#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

perl $HIPSCI_CODE/scripts/indexes/ena_index.analyses.es.pl \
 -era_password $RESEQTRACK_PASS \
 -sequencing_study_id ERP006946 \
 -sequencing_study_id ERP007111 \
 -sequencing_study_id ERP013161 \
 -sequencing_study_id ERP013162 \
 -sequencing_study_id ERP013436 \
 -analysis_study_id ERP013157=ERP006946 \
 -analysis_study_id ERP013158=ERP006946 \
 -demographic /nfs/research2/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
