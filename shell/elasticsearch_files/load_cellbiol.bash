#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# Run this one whenver new cellular phenotyping images get put on the public ftp site

perl $HIPSCI_CODE/scripts/indexes/cellbiol-fn.es.pl \
  -demographic /nfs/research1/hipsci/tracking_resources/demographic_spreadsheets/Demographicdata_HipSci_2016-12-02.csv
