#!/bin/bash

FROM=/nfs/research2/hipsci/drop/hip-drop/tracked
TO=/hps/nobackup/research/hipsci/tracked

rsync -ptgomr --delete-during --include='*/' --include='*.vcf' --include='*.vcf.gz' --include='*.vcf.gz' --exclude='*' ${FROM}/ $TO

FROM=/nfs/research2/hipsci/controlled
TO=/hps/nobackup/research/hipsci/controlled

rsync -ptgomr --delete-during --include='*/' --include='*.vcf' --include='*.vcf.gz' --include='*.vcf.gz' --exclude='*' ${FROM}/ $TO
