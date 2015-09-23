#!/bin/bash

UPDATE_SERVER=$1
UPDATE_SCRIPTS=/homes/peter/elasticsearch_update_scripts
(
source /homes/peter/elasticsearch_update_scripts/required_exports_dontgit \
&& $UPDATE_SCRIPTS/01populate_from_cgap.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/02update_demographics.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/03update_assays.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/04update_qc1.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/05update_proteomics.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/06update_qc1_images.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/07update_cellbiol-fn.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/08update_array_assays.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/10update_ebisc_name.bash $UPDATE_SERVER | head \
&& $UPDATE_SCRIPTS/11update_hla_typing.bash $UPDATE_SERVER | head
) 2> >(grep -v 'Use of uninitialized.*Text/Delimited.pm' 1>&2)