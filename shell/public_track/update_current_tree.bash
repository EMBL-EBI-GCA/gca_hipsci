#!/bin/bash
perl $RESEQTRACK/scripts/file/run_tree_for_ftp.pl \
  -dbname hipsci_track -dbhost mysql-g1kdcc-public -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS \
  -dir_to_tree /nfs/hipsci/vol1/ftp \
  -staging_dir /nfs/1000g-work/hipsci/archive_staging/ftp \
  -old_tree_dir /nfs/hipsci/vol1/ftp \
  -old_changelog_dir /nfs/hipsci/vol1/ftp \
  -log_dir /homes/hipdcc/logs/hipsci_ftp_tree_logs