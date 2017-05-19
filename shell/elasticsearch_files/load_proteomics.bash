#!/bin/bash

HIPSCI_CODE=`dirname $0`/../..

perl $HIPSCI_CODE/scripts/indexes/proteomics.es.pl \
  -dataset PXD003903 \
  -dataset PXD005506
