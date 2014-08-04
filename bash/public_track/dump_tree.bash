#!/bin/bash

staging=/nfs/1000g-work/hipsci/archive_staging/ftp

perl $RESEQTRACK/scripts/file/run_tree_for_ftp.pl \
  -dbname hipsci_track -dbhost mysql-g1kdcc-public -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS \
  -dir_to_tree /nfs/hipsci/vol1/ftp \
  -staging_dir $staging \
  -log_dir $PWD \
