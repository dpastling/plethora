#!/usr/bin/env bash
#BSUB -J gc_correct[1-300]
#BSUB -o logs/gc_correction_%J.out
#BSUB -e logs/gc_correction_%J.err
#BSUB -R "select[mem>10] rusage[mem=10]"
#BSUB -P 1000Genomes

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

bed_file=$bed_dir/${sample}_read_depth.bed
gc_model=`echo $master_ref | sed 's/.bed/_GC.txt/'`

Rscript code/gc_correction.R $bed_file $gc_model


