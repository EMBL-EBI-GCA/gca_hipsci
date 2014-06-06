#!/bin/bash

perl $HIPSCI_CODE/scripts/proteomics/dump_proteomics_maxquant_index.pl \
  -dbuser g1kro -dbport 4197 -dbname hipsci_private_track -dbhost mysql-g1kdcc-public \
  -type PROT_TXT \
  > proteomics.maxquant.index \
&& mv -f proteomics.maxquant.index /nfs/research2/hipsci/drop/hip-drop/tracked/proteomics/maxquant \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_private_track -dbhost mysql-g1kdcc-public \
  -file /nfs/research2/hipsci/drop/hip-drop/tracked/proteomics/maxquant/proteomics.maxquant.index \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5
