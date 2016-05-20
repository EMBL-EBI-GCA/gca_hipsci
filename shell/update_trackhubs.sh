#!/bin/bash

perl $HIPSCI_CODE/scripts/trackhubs/trackhub.pl \
-THR_username hipsci \
-THR_password $THR_pass \
-server_dir_full_path /homes/peter/tracktest/\.TrackHubs \
-server_url BLAH \
-exomeseq /nfs/hipsci/vol1/ftp/archive_datasets/ENA.ERP006946.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq /nfs/hipsci/vol1/ftp/archive_datasets/ENA.ERP013157.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq /nfs/hipsci/vol1/ftp/archive_datasets/ENA.ERP013158.exomeseq.healthy_volunteers.analysis_files.tsv