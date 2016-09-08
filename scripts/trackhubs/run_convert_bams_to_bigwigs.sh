#!/bin/bash

#Note you must be in a threaded perl environment "perlbrew use perl-5.16.3_RH7_threaded"
#Requires bam2bw from PCAP-core https://github.com/ICGC-TCGA-PanCancer/PCAP-core

source ~/.pcap_bashrc \
#&& import_new_bams.pl -bamfilelists /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/ENA.ERP007111.rnaseq.healthy_volunteers.analysis_files.tsv -bamlocaldir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbams
&& perl convert_bams_to_bigwigs.pl -bamlocaldir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbams -wigoutputdir /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/starbigwigs -reference /nfs/production/reseq-info/scratch/hipdcc/hipsci/trackhub_files/reference/hs37d5.fa -flags 3844 -bamToBwpath /nfs/production/reseq-info/work/hipdcc/PCAP-core/bin/bamToBw.pl -farmlogfolder /nfs/production/reseq-info/work/hipdcc/PCAP-core-base/bam2bwlogs