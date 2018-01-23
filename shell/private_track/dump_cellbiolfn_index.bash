#!/bin/bash

datestamp=`date +%Y%m%d`

mysql --user=g1kro --port=4197 --host=mysql-g1kdcc-public hipsci_cellbiolfn \
  -e 'select cl.name as cell_line from experiment e, cell_line cl where e.cell_line_id=cl.cell_line_id and e.is_production=1 group by cl.cell_line_id' \
  > cellbiol-fn.$datestamp.index \
&& mv -f cellbiol-fn.$datestamp.index /nfs/research1/hipsci/drop/hip-drop/tracked/cellbiol-fn/ \
&& perl $RESEQTRACK/scripts/file/load_files.pl  \
  -dbuser g1krw -dbport 4197 -dbpass $RESEQTRACK_PASS -dbname hipsci_private_track -dbhost mysql-g1kdcc-public \
  -file /nfs/research1/hipsci/drop/hip-drop/tracked/cellbiol-fn/cellbiol-fn.$datestamp.index \
  -host 1000genomes.ebi.ac.uk \
  -run \
  -update \
  -do_md5
