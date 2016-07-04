#!/bin/bash

SERVER=ves-hx-e3:9200

(
perl $HIPSCI_CODE/scripts/elasticsearch/alert_removed_cell_line.from_cgap_report.pl \
	-es_host=$SERVER
) 2> >(grep -v 'Use of uninitialized.*Text/Delimited.pm' 1>&2)
