#!/bin/bash
SERVER=$1
curl -XPUT http://localhost:9200/_snapshot/$SERVER/hipsci_snapshot_$(date +\%Y\%m\%d\%H\%M\%S) -d '{"indices": "hipsci"}'