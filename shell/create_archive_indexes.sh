#!/bin/bash

perl $HIPSCI_CODE/scripts/indexes/ena_index.runs.pl \
  -era_password $RESEQTRACK_PASS \
  -study_id ERP006946 \
  -study_id ERP007111 \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv

perl $HIPSCI_CODE/scripts/indexes/ena_index.analyses.pl \
  -era_password $RESEQTRACK_PASS \
  -study_id ERP006946 \
  -study_id ERP007111 \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.runs.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset_id EGAD00001001437 \
  -dataset_id EGAD00001001438 \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.analyses.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset_id EGAD00001001437 \
  -dataset_id EGAD00001001438 \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset EGAD00010000773=/nfs/research2/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.201411.tsv \
  -dataset EGAD00010000771=/nfs/research2/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.201504.tsv \
  -dataset EGAD00010000775=/nfs/research2/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.201411.tsv \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv
