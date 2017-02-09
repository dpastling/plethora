#!/usr/bin/env bash
#BSUB -J download[13-14]%5
#BSUB -e logs/download_%J.log
#BSUB -o logs/download_%J.out
#BSUB -R "select[mem>2] rusage[mem=2] span[hosts=1]"
#BSUB -q normal
#BSUB -n 1
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

code/download_sample.pl $sample $sample_index

