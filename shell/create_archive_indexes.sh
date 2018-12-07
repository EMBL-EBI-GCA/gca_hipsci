#!/bin/bash
#
#perl $HIPSCI_CODE/scripts/indexes/ena_index.runs.pl \
#  $ERA_DB_ARGS \
#  -study_id ERP006946 \
#  -study_id ERP007111 \
#  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
#
#perl $HIPSCI_CODE/scripts/indexes/ena_index.analyses.pl \
#  $ERA_DB_ARGS \
#  -study_id ERP006946 \
#  -study_id ERP007111 \
#  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
#
#perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.runs.pl \
#  $ERA_DB_ARGS \
#  -dataset_id EGAD00001001437 \
#  -dataset_id EGAD00001001438 \
#  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
#
#perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.pl \
#  $ERA_DB_ARGS \
#  -dataset_id EGAD00001001437 \
#  -dataset_id EGAD00001001438 \
#  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.pl \
  $ERA_DB_ARGS \
  -dataset EGAD00010000773=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.201411.tsv \
  -dataset EGAD00010000771=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.201504.tsv \
  -dataset EGAD00010000775=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.201411.tsv \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
