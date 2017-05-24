#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

# The command line should contain *EVERY* current pride id for a proteomics submission
# Add any new ids before running this script.

perl $HIPSCI_CODE/scripts/indexes/proteomics.es.pl \
  -dataset PXD003903 \
  -dataset PXD005506
