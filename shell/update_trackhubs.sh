#!/bin/bash

perl $HIPSCI_CODE/scripts/trackhubs/trackhub.pl \
-THR_username $THR_user \
-THR_password $THR_pass \
-server_dir_full_path /nfs/hipsci/vol1/ftp/\.TrackHubs \
-server_url ftp://ftp.hipsci.ebi.ac.uk/vol1/ftp/\.TrackHubs \
-hubname hipsci_hub \
-long_description 'Human Induced Pluripotent Stem Cells Initiative (HipSci) TrackHub' \
-email 'hipsci-dcc@ebi.ac.uk' \
-assembly hg19 \
-about_url http://www.hipsci.org/about \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP006946.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013157.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013158.exomeseq.healthy_volunteers.analysis_files.tsv \

