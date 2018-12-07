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
  -dataset EGAD00010001344=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002005.gtarray.201812.tsv \
  -dataset EGAD00010001346=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002006.gtarray.201812.tsv \
  -dataset EGAD00010001348=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002007.gtarray.201812.tsv \
  -dataset EGAD00010001350=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002008.gtarray.201812.tsv \
  -dataset EGAD00010001352=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002009.gtarray.201812.tsv \
  -dataset EGAD00010001354=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002010.gtarray.201812.tsv \
  -dataset EGAD00010001356=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002011.gtarray.201812.tsv \
  -dataset EGAD00010001360=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002013.gtarray.201812.tsv \
  -dataset EGAD00010001362=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002014.gtarray.201812.tsv \
  -dataset EGAD00010001364=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002015.gtarray.201812.tsv \
  -dataset EGAD00010001366=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002016.gtarray.201812.tsv \
  -dataset EGAD00010001368=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002020.gexarray.201812.tsv \
  -dataset EGAD00010001370=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002021.gexarray.201812.tsv \
  -dataset EGAD00010001372=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002022.gexarray.201812.tsv \
  -dataset EGAD00010001374=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002023.gexarray.201812.tsv \
  -dataset EGAD00010001376=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002024.gexarray.201812.tsv \
  -dataset EGAD00010001378=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002025.gexarray.201812.tsv \
  -dataset EGAD00010001380=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002026.gexarray.201812.tsv \
  -dataset EGAD00010001382=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002027.gexarray.201812.tsv \
  -dataset EGAD00010001384=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002028.gexarray.201812.tsv \
  -dataset EGAD00010001386=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002029.gexarray.201812.tsv \
  -dataset EGAD00010001388=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002030.gexarray.201812.tsv \
  -dataset EGAD00010001390=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002031.gexarray.201812.tsv \
  -dataset EGAD00010000910=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001729.gexarray.201812.tsv \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv

#  # Below were removed because the study_ids were already included in load_ega_arrays.bash file.
#  -dataset EGAD00010000773=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000866.gtarray.201411.tsv \
#  -dataset EGAD00010000771=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000865.mtarray.201504.tsv \
#  -dataset EGAD00010000775=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001000867.gexarray.201411.tsv \

#  -dataset EGAD00010001358=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001002012.gtarray.201812.tsv \
#  -dataset EGAD00010000909=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001728.mtarray.201812.tsv \
#  -dataset EGAD00010000911=/nfs/research1/hipsci/tracking_resources/ega_array_data_submissions/EGAS00001001730.gtarray.201812.tsv \
