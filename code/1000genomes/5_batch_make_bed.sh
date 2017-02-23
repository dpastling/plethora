#!/usr/bin/env bash
#BSUB -J coverage[1-300]%5
#BSUB -e logs/coverage_%J.log
#BSUB -o logs/coverage_%J.out
#BSUB -R "select[mem>40] rusage[mem=40] span[hosts=1]"
#BSUB -n 12
#BSUB -q normal
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

bam_file=$alignment_dir/$sample.bam
bed_file=$bed_dir/$sample

code/make_bed.sh -r $master_ref -p "paired" -b $bam_file -o $bed_file

