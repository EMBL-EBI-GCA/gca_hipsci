#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ega dataset id for array-based experiments (gtarray, mtarray, gexarray)
# Remove old dataset ids from this command line, and add any new ones before running this script.
# The command line format is: -dataset {DATASET_ID}=/path/to/submission/file.txt
# The submission file is the tab-delimited text file which was sent to EGA to create the dataset.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.es.pl \
  -era_password $RESEQTRACK_PASS \
  -dataset EGAD00010000564=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000566=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000568=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000771=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000773=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000775=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000777=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001272.gtarray.201411.tsv \
  -dataset EGAD00010000779=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001273.gtarray.201411.tsv \
  -dataset EGAD00010000781=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000783=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000785=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001277.gexarray.201411.tsv \
  -dataset EGAD00010000817=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000909=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000910=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010000911=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001139=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.20161212.txt \
  -dataset EGAD00010001143=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.20161212.txt \
  -dataset EGAD00010001145=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001274.mtarray.20161212.txt \
  -dataset EGAD00010001147=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.20161212.txt \
  -dataset EGAD00010001149=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001275.mtarray.20161212.txt \
  -dataset EGAD00010001328=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001330=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001332=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001334=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001340=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001342=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001344=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001346=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001348=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001350=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001352=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001354=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001356=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001358=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001360=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001362=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001364=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001366=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001368=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001370=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001372=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001374=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001376=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001378=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001380=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001382=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001384=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001386=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001388=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -dataset EGAD00010001390=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/ \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv



 