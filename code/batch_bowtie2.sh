#!/usr/bin/env bash
#BSUB -J align[1-5]%10
#BSUB -e logs/bowtie2_%J.log
#BSUB -o logs/bowtie2_%J.out
#BSUB -R "select[mem>5] rusage[mem=5] span[hosts=1]"
#BSUB -q normal
#BSUB -n 12
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

code/download_sample.pl $sample $sample_index

# Bowtie requires that the file names be concatenated with a comma
first_pair=`find fastq/$sample -name '*_1.filt.fastq.gz'  | perl -pe 's/\n/,/g'`
second_pair=`find fastq/$sample -name '*_2.filt.fastq.gz' | perl -pe 's/\n/,/g'`

bowtie2 -p 12 $bowtie_params --very-sensitive --minins 0 --maxins 2000 -x $genome -1 $first_pair -2 $second_pair | samtools view -hSb - > $alignment_dir/${sample}.bam

