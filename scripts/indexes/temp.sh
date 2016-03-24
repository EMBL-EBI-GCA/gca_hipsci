#!/bin/bash

perl $HIPSCI_CODE/scripts/indexes/ena_index.analyses.es.pl \
  -era_password $RESEQTRACK_PASS \
  -study_id ERP013161 \
  -study_id ERP013162 \
  -demographic /nfs/production/reseq-info/work/streeter/hipsci/resources/Demographicdata_HipSci_2015-05-19.csv
