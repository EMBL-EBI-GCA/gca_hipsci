#!/bin/bash

perl dump_tree.pl \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipcsi_private_track -dbhost mysql-g1kdcc-public \
  -tree_dir /nfs/research2/hipsci/drop/hip-drop/tracked \
  -relative_to_dir /nfs/research2/hipsci/drop/hip-drop \
  > current.tree \
&& mv -f current.tree /nfs/research2/hipsci/drop/hip-drop/ \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipcsi_private_track -dbhost mysql-g1kdcc-public \
  -file /nfs/research2/hipsci/drop/hip-drop/current.tree \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5

perl dump_tree.pl \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipcsi_private_track -dbhost mysql-g1kdcc-public \
  -tree_dir /nfs/research2/hipsci/controlled \
  > current.controlled.tree \
&& mv -f current.controlled.tree /nfs/research2/hipsci/controlled \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipcsi_private_track -dbhost mysql-g1kdcc-public \
  -file /nfs/research2/hipsci/controlled/current.controlled.tree \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5
