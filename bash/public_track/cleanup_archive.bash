#!/bin/bash

perl $RESEQTRACK/scripts/file/cleanup_archive.pl \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_track -dbhost mysql-g1kdcc-public \
