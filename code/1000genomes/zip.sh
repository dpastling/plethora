#!/usr/bin/env bash
#BSUB -J clean[1-300]%10
#BSUB -e logs/zip_%J.log
#BSUB -o logs/zip_%J.out
#BSUB -R "select[mem>30] rusage[mem=30] span[hosts=1]"
#BSUB -q normal
#BSUB -n 1

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

bed_file=results/${sample}_sorted.bed
n_align=`cut -f 4 $bed_file | sort -T ./ | uniq | wc -l`
echo $sample $n_align >> align_report.txt
gzip $bed_file


