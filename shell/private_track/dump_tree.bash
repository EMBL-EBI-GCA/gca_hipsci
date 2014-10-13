#!/bin/bash

perl $RESEQTRACK/scripts/file/dump_tree.pl \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_private_track -dbhost mysql-g1kdcc-public \
  -output_path /nfs/research2/hipsci/drop/hip-drop/current.tree \
  -dir_to_tree /nfs/research2/hipsci/drop/hip-drop/tracked \
  -trim_dir /nfs/research2/hipsci/drop/hip-drop/ \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_private_track -dbhost mysql-g1kdcc-public \
  -file /nfs/research2/hipsci/drop/hip-drop/current.tree \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5
