#!/usr/bin/env bash
#BSUB -J trim[1-300]%5
#BSUB -e logs/trim_%J.log
#BSUB -o logs/trim_%J.out
#BSUB -R "select[mem>20] rusage[mem=20] span[hosts=1]"
#BSUB -q normal
#BSUB -n 1
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/1000genomes/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

ideal_files=`grep $sample $sample_index | wc -l`
actual_files=`ls fastq/$sample/*_[12].fastq.gz | wc -l`

if [ $ideal_files != $actual_files ]
then
    echo "download is not complete for sample $sample"
    exit 1
fi

for first_read in fastq/$sample/*_1.fastq.gz
do
second_read=`echo $first_read | sed 's/_1.fastq/_2.fastq/'`
first_filtered=`echo $first_read | sed 's/_1.fastq/_1_filtered.fastq/'`
second_filtered=`echo $second_read | sed 's/_2.fastq/_2_filtered.fastq/'`
cutadapt -a XXX -A XXX -q 10 --minimum-length 80 --trim-n -o $first_filtered -p $second_filtered $first_read $second_read
done

