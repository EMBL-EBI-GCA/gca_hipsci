#!/bin/bash

(
perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/biosample_present_in_cgap_report.pl SAMEG120702 SAMEG178795

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/cell_line_is_in_biosamples.pl

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/ega_has_correct_biosample_id.pl -study EGAS00001000592 -pass $RESEQTRACK_PASS -era ERAPRO

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/num_samples_is_increasing.pl

) 2> >(grep -v 'Use of uninitialized.*Text/Delimited.pm' 1>&2)
