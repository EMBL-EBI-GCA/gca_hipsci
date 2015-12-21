#!/bin/bash

SERVER1=$1
SERVER2=$2

(
perl $HIPSCI_CODE/scripts/elasticsearch/alert_removed_cell_line.from_cgap_report.pl \
	-es_host=$SERVER1:9200 -es_host=$SERVER2:9200
) 2> >(grep -v 'Use of uninitialized.*Text/Delimited.pm' 1>&2)
