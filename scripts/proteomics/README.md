
Scripts in this directory, from most to least important:

### 1. reheader_tmt_file.pl

This script has pod documentation explaining what it does. Also see the [confluence page](https://www.ebi.ac.uk/seqdb/confluence/display/1000GEN/Proteomics+MaxQuant+data).

This script must be run on any maxquant data we receive from Dundee.

### 2. create_tmt_readme.pl

This script has pod documentation explaining what it does. Also see the [confluence page](https://www.ebi.ac.uk/seqdb/confluence/display/1000GEN/Proteomics+MaxQuant+data).

Use this script to create a new readme file describing each new maxquant data set we receive from Dundee.

### 3. dump_proteomics_raw_index.pl

This script is used to occasionally generate an index file listing all proteomics raw data we have received. The output index file lives in this directory: /nfs/research1/hipsci/drop/hip-drop/tracked/proteomics.

This is low importance. I don't think anyone ever looks at the index file.

### 4. pride_pilot_submission.pl

This script was used to create the .px file when we submitted the pilot study to PRIDE. This script will never get run again. But it is a useful record of how the .px file got generated.

### 5. make_submission_px.pl

This script was written in the early datys when we were planning to automate submissions to PRIDE. The project has moved on, and so this script will probably never be used. But it is a useful record of how a .px submission file could be made.
