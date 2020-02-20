#!/bin/bash

SERVER=ves-hx-e4:9200

perl $HIPSCI_CODE/scripts/elasticsearch/update_cell_line.differentiations.pl \
  -es_host=$SERVER \
  --yaml=$HIPSCI_CODE/tracking_resources/differentiations/macrophage_2016.yaml \
  --yaml=$HIPSCI_CODE/tracking_resources/differentiations/sensory_neurons_2016.yaml \
