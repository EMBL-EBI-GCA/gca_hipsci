#!/bin/bash

perl $RESEQTRACK/scripts/file/run_tree_for_ftp.pl \
  -dbname hipsci_track -dbhost mysql-g1kdcc-public -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS \
  -skip_load -skip_archive \
  -dir_to_tree /nfs/hipsci/vol1/ftp \
  -staging_dir /nfs/1000g-work/hipsci/archive_staging/ftp \
  -log_dir $PWD/logging_dir
