#!/usr/bin/env bash
#BSUB -J clean[104,110,112,113,118-121,124-128,130,131]%5
#BSUB -e logs/clean_%J.log
#BSUB -o logs/clean_%J.out
#BSUB -R "select[mem>5] rusage[mem=5] span[hosts=1]"
#BSUB -q normal
#BSUB -n 1
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

code/clean_files.pl --rm-fastq $sample


