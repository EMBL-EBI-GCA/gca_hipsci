#!/bin/bash

perl $HIPSCI_CODE/scripts/trackhubs/create_trackhub.pl \
-server_dir_full_path /homes/peter/tracktest/TrackHub \ #/nfs/1000g-work/hipsci/archive_staging/ftp/TrackHub
-hubname hipsci_hub \
-long_description 'Human Induced Pluripotent Stem Cells Initiative (HipSci) TrackHub' \
-email 'hipsci-dcc@ebi.ac.uk' \
-assembly hg19 \
-about_url http://www.hipsci.org/about \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP006946.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013157.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013158.exomeseq.healthy_volunteers.analysis_files.tsv \
#Archive files script here
#perl $HIPSCI_CODE/scripts/trackhubs/register_trackhub.pl \
#-THR_username $THR_user \
#-THR_password $THR_pass \
#-hubname hipsci_hub \
#-server_url ftp://ftp.hipsci.ebi.ac.uk/vol1/ftp/\.TrackHub \