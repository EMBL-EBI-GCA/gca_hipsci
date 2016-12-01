#!/bin/bash

ME=`whoami`
if [ $ME != reseq_adm ]; then
  echo run this script as reseq_adm
  exit 1
fi

BASE=${BASE:-/nfs/public/rw/reseq-info}

for ES_BASE in $BASE/elasticsearch $BASE/elasticsearch_staging; do
  umask 0022
  mkdir -p $ES_BASE $ES_BASE/gca_elasticsearch $ES_BASE/snapshot_repo $ES_BASE/var
  git clone ssh://git@github.com/EMBL-EBI-GCA/gca_elasticsearch.git $ES_BASE/gca_elasticsearch
  mkdir -p $ES_BASE/gca_elasticsearch/config/scripts

  for type in cellLine donor file; do
    ln -sfT $ES_BASE/gca_hipsci_browser/elasticsearch_settings/scripts/hipsci_${type}_transform.groovy $ES_BASE/gca_elasticsearch/config/scripts/hipsci_${type}_transform.groovy
  done

  umask 0002
  mkdir -p $ES_BASE/var/log $ES_BASE/snapshot_repo/hipsci_repo
done

HIPSCI_BASE=$BASE/hipsci_portal_staging

umask 0022
mkdir -p $HIPSCI_BASE $HIPSCI_BASE/var/log $HIPSCI_BASE/var/run $HIPSCI_BASE/www_static
git clone ssh://git@github.com/EMBL-EBI-GCA/gca_elasticsearch.git $HIPSCI_BASE/gca_elasticsearch
git clone ssh://git@github.com/EMBL-EBI-GCA/gca_hipsci_browser.git $HIPSCI_BASE/gca_hipsci_browser
git clone https://github.com/hipsci/hipsci.github.io.git $HIPSCI_BASE/hipsci.github.io.git

umask 0002
mkdir -p $HIPSCI_BASE/var/log/hx $HIPSCI_BASE/var/run/hx

HIPSCI_BASE=$BASE/hipsci_portal
mkdir -p $HIPSCI_BASE $HIPSCI_BASE/var/log $HIPSCI_BASE/var/run $HIPSCI_BASE/www_static
git clone ssh://git@github.com/EMBL-EBI-GCA/gca_elasticsearch.git $HIPSCI_BASE/gca_elasticsearch
git clone ssh://git@github.com/EMBL-EBI-GCA/gca_hipsci_browser.git $HIPSCI_BASE/gca_hipsci_browser

umask 0002
mkdir -p $HIPSCI_BASE/var/log/hx $HIPSCI_BASE/var/run/hx
