#!/bin/bash

#Requires bam2bw from cgpBigWig https://github.com/cancerit/cgpBigWig

source ~/.cgpBigWig_bashrc \
&& perl convert_bams_to_bigwigs.pl -bamlocaldir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbams -wigoutputdir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbigwigs -reference /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/reference/hs37d5.fa -flags 3844 -bamToBwpath /nfs/production/reseq-info/work/hipdcc/cgpBigWig-bin/bin/bam2Bw -farmlogfolder /nfs/production/reseq-info/work/hipdcc/cgpBigWig-bin/bam2bwlogs