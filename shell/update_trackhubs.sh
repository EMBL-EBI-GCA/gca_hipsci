#!/bin/bash

#Servers for production
#-server_dir_full_path /nfs/1000g-work/hipsci/archive_staging/ftp/TrackHub
#-server_url ftp://ftp.hipsci.ebi.ac.uk/vol1/ftp/TrackHub

#Servers for test
#-server_dir_full_path /homes/peter/tracktest/TrackHub
#-server_url http://www.ebi.ac.uk/~peter/tracktest/TrackHub

perl $HIPSCI_CODE/scripts/trackhubs/create_trackhub.pl \
-server_dir_full_path /nfs/1000g-work/hipsci/archive_staging/ftp/TrackHub \
-hubname hipsci_hub \
-long_description 'Human Induced Pluripotent Stem Cells Initiative (HipSci) TrackHub' \
-email 'hipsci-dcc@ebi.ac.uk' \
-assembly hg19 \
-about_url http://www.hipsci.org/about \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP006946.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013157.exomeseq.healthy_volunteers.analysis_files.tsv \
-exomeseq $HIPSCI_FTP/archive_datasets/ENA.ERP013158.exomeseq.healthy_volunteers.analysis_files.tsv \
&& perl $RESEQTRACK/scripts/file/archive_files.pl -dbhost mysql-g1kdcc-public -dbuser $G1K_user -dbpass $G1K_pass -dbport 4197 -dbname hipsci_track -action archive -skip -run -priority 99 -dir /nfs/1000g-work/hipsci/archive_staging/ftp/TrackHub \
&& perl $RESEQTRACK/scripts/file/cleanup_archive.pl -dbhost mysql-g1kdcc-public -dbuser $G1K_user -dbpass $G1K_pass -dbport 4197 -dbname hipsci_track -loop 1 \
&& perl $HIPSCI_CODE/scripts/trackhubs/register_trackhub.pl \
-THR_username $THR_user \
-THR_password $THR_pass \
-server_url http://ftp.hipsci.ebi.ac.uk/vol1/ftp/ \
-hubname hipsci_hub \
