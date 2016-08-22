#!/bin/bash

FROM=/nfs/research2/hipsci/drop/hip-drop/tracked
TO=yoda-login:/hps/nobackup/hipsci/tracked

rsync -ptgomr -e "ssh -o StrictHostKeyChecking=no" --delete-during --include='*/' --include='*.vcf' --include='*.vcf.gz' --include='*.vcf.gz' --exclude='*' ${FROM}/ $TO

FROM=/nfs/research2/hipsci/controlled
TO=yoda-login:/hps/nobackup/hipsci/controlled

rsync -ptgomr -e "ssh -o StrictHostKeyChecking=no" --delete-during --include='*/' --include='*.vcf' --include='*.vcf.gz' --include='*.vcf.gz' --exclude='*' ${FROM}/ $TO
