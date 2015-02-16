#!/bin/bash

export PERL5LIB=$PERL5LIB:$HIPSCI_CODE/lib:$RESEQTRACK/modules

(
perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/group_is_updating.pl SAMEG120702

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/biosample_present_in_cgap_report.pl SAMEG120702 | head

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/cell_line_is_in_biosamples.pl SAMEG120702 | head

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/ega_has_correct_biosample_id.pl -study EGAS00001000592 -pass $RESEQTRACK_PASS -era ERAPRO | head

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/ega_has_correct_biosample_id.pl -study EGAS00001000593 -pass $RESEQTRACK_PASS -era ERAPRO | head

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/num_samples_is_increasing.pl | head

perl $HIPSCI_CODE/scripts/cgap_reports/consistency_checks/withdrawn_samples.pl | head

) 2> >(grep -v 'Use of uninitialized.*Text/Delimited.pm' 1>&2)
