#!/bin/bash

datestamp=`date +%Y%m%d`
staging=/nfs/1000g-work/hipsci/archive_staging/ftp

perl $HIPSCI_CODE/scripts/file/dump_tree.pl \
  -dbuser g1kro -dbport 4197 -dbname hipsci_track -dbhost mysql-g1kdcc-public \
  -tree_dir /nfs/hipsci/vol1/ftp/ \
  -relative_to_dir /nfs/hipsci/vol1/ \
  > current.tree \
&& mv -f current.tree $staging \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_track -dbhost mysql-g1kdcc-public \
  -file $staging/current.tree \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5 \
&& perl $RESEQTRACK/scripts/file/archive_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_track -dbhost mysql-g1kdcc-public \
  -file $staging/current.tree \
  -action archive \
  -run \
  -priority 99 \
  -skip
