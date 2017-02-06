#!/usr/bin/env bash
#BSUB -J align[1-300]%20
#BSUB -e logs/bowtie2_%J.log
#BSUB -o logs/bowtie2_%J.out
#BSUB -R "select[mem>5] rusage[mem=5] span[hosts=1]"
#BSUB -q normal
#BSUB -n 12
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

code/download_sample.pl $sample $sample_index

# Bowtie requires that the file names be concatenated with a comma
first_pair=`find fastq/$sample -name '*_1.filt.fastq.gz'  | perl -pe 's/\n/,/g'`
second_pair=`find fastq/$sample -name '*_2.filt.fastq.gz' | perl -pe 's/\n/,/g'`

code/bowtie2.sh -i 800 -g $genome -b $alignment_dir/${sample}.bam $first_pair $second_pair


