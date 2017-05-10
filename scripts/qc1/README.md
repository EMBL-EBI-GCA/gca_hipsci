# Processing new QC1 data

Our friends at WTSI occasionally copy a complete new set of QC1 data onto disk in Hinxton.
The QC1 files are archived on our public FTP site which is on disk in Hemel.

All scripts have pod documentation, which tells you command line options, and gives examples of how to run.

### First, calculate new actions to take

You must run the following four scripts on a Hinxton login node:

* aberrant_polysomy_to_public_ftp.pl
* cnv_aberrant_regions_to_public_ftp.pl
* copy_number_to_public_ftp.pl
* pluritest_to_public_ftp.pl

Those scripts take the following actions:

1. Work out which qc1 files are new (not yet on the public FTP site) - these files must be copied from Hinxton to Hemel, loaded into the database, and archived.
2. Work out which FTP files are old - these files must be dearchived from the public FTP site

These scripts use file sizes and md5s to work out if a FTP file is different from the new version.
The scripts are responsible for working out the correct name and file path of the incoming data.

These script do not take any actions on the actual files, i.e. they do not move, rename, copy, archive, dearchive etc.
The stdout from these scripts is a list of commands, which should be fed into the script run_actions.pl as stdin, described in the next section....

### Next, run the actions

    perl run_actions.pl -dbpass=$RESEQTRACK_PASS < output_from_other_script.txt

This script must be run in Hemel, so that it can see the archive directory and staging directory.

This script is for running the actions calculated by the other scripts in this directory. Specifically:
  
1. copies files by rsync from Hinxton disk to Hemel disk (archive staging)
2. loads new files into the database
3. archives new files
4. dearchives old files

This scripts reads in the stdout produced by the other scripts in this directory. It takes actions based on what it is told by the other scripts.
