#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ega dataset id for array-based experiments (gtarray, mtarray, gexarray)
# Remove old dataset ids from this command line, and add any new ones before running this script.
# The command line format is: -dataset {DATASET_ID}=/path/to/submission/file.txt
# The submission file is the tab-delimited text file which was sent to EGA to create the dataset.

perl $HIPSCI_CODE/scripts/indexes/ega_dataset_index.arrays.es.pl \
  $ERA_DB_ARGS \
  -dataset EGAD00010001147=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.20161212.txt \
  -dataset EGAD00010001139=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.20161212.txt \
  -dataset EGAD00010001143=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.20161212.txt \
  -dataset EGAD00010000777=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001272.gtarray.201411.tsv \
  -dataset EGAD00010000779=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001273.gtarray.201411.tsv \
  -dataset EGAD00010001145=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001274.mtarray.20161212.txt \
  -dataset EGAD00010001149=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001275.mtarray.20161212.txt \
  -dataset EGAD00010000783=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001276.gexarray.201411.tsv \
  -dataset EGAD00010000785=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001277.gexarray.201411.tsv \
  -dataset EGAD00010001344=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002005.gtarray.201812.tsv \
  -dataset EGAD00010001346=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002006.gtarray.201812.tsv \
  -dataset EGAD00010001348=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002007.gtarray.201812.tsv \
  -dataset EGAD00010001350=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002008.gtarray.201812.tsv \
  -dataset EGAD00010001352=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002009.gtarray.201812.tsv \
  -dataset EGAD00010001354=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002010.gtarray.201812.tsv \
  -dataset EGAD00010001356=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002011.gtarray.201812.tsv \
  -dataset EGAD00010001358=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002012.gtarray.201812.tsv \
  -dataset EGAD00010001360=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002013.gtarray.201812.tsv \
  -dataset EGAD00010001362=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002014.gtarray.201812.tsv \
  -dataset EGAD00010001364=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002015.gtarray.201812.tsv \
  -dataset EGAD00010001366=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002016.gtarray.201812.tsv \
  -dataset EGAD00010001368=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002020.gexarray.201812.tsv \
  -dataset EGAD00010001370=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002021.gexarray.201812.tsv \
  -dataset EGAD00010001372=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002022.gexarray.201812.tsv \
  -dataset EGAD00010001374=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002023.gexarray.201812.tsv \
  -dataset EGAD00010001376=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002024.gexarray.201812.tsv \
  -dataset EGAD00010001378=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002025.gexarray.201812.tsv \
  -dataset EGAD00010001380=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002026.gexarray.201812.tsv \
  -dataset EGAD00010001382=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002027.gexarray.201812.tsv \
  -dataset EGAD00010001384=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002028.gexarray.201812.tsv \
  -dataset EGAD00010001386=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002029.gexarray.201812.tsv \
  -dataset EGAD00010001388=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002030.gexarray.201812.tsv \
  -dataset EGAD00010001390=/nfs/nobackup/reseq-info/ega/dataset_output_files/EGAS00001002031.gexarray.201812.tsv \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv

#  for Embryonic Stem Cells:
#    -dataset EGAD00010000909=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001728.mtarray.201812.tsv
#    -dataset EGAD00010000910=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001729.gexarray.201812.tsv
#    -dataset EGAD00010000911=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001730.gtarray.201812.tsv
