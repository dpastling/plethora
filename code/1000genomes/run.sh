#!/usr/bin/env bash
#BSUB -J run
#BSUB -o logs/run_%J.out
#BSUB -e logs/run_%J.err

bsub < code/1000genomes/1_download.sh
bsub -w "done(download[*])" < code/1000genomes/2_trim.sh
bsub -w "done(trim[*])" < code/1000genomes/3_batch_bowtie.sh
bsub -w "done(align[*])" < code/1000genomes/4_batch_clean.sh
bsub -w "done(clean[*])" < code/1000genomes/5_batch_make_bed.sh
bsub -w "done(coverage[*])" < code/1000genomes/4_batch_clean.sh
bsub -w "done(clean[*])" < code/1000genomes/7_batch_gc_correction.sh



