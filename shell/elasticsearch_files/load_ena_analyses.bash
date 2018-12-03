#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current ena project id.
# The study_id is the id of a exomeseq, rnaseq, wgs or gtarray experiment.
# the -analysis_study_id flag is for ena projects comprising analysed data where the script needs to look up the corresponding run data from a different project.
# Format is: -analysis_study_id {ANALYSIS_STUDY_ID}={RAW_SEQUENCING_STUDY_ID}
# Add any new ids to this command line before running this script.

perl $HIPSCI_CODE/scripts/indexes/ena_index.analyses.es.pl \
 $ERA_DB_ARGS \
 -study_id ERP006946 \
 -study_id ERP007111 \
 -study_id ERP013161 \
 -study_id ERP013162 \
 -study_id ERP013436 \
 -study_id ERP017015 \
 -study_id ERP016335 \
 -analysis_study_id ERP013157=ERP006946 \
 -analysis_study_id ERP013158=ERP006946 \
 -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
