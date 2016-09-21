#!/usr/bin/env bash
#BSUB -J coverage[1-5]%5
#BSUB -e logs/coverage_%J.log
#BSUB -o logs/coverage_%J.out
#BSUB -R "select[mem>40] rusage[mem=40]"
#BSUB -q normal
#BSUB -P Sikela

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

source code/config.sh

# LSB_JOBINDEX is the job array position
sample=${SAMPLES[$(($LSB_JOBINDEX - 1))]}

bam_file=$alignment_dir/${sample}
bed_file=$bed_dir/$sample

## Convert alignment file to a bed format
samtools sort -n -@ 5 -m 5G $bam_file.bam ${bam_file}_sorted
bedtools bamtobed -bedpe -split -i ${bam_file}_sorted.bam > $bed_file.bed

# remove alignment files if bed has correct number of reads
code/clean_files.pl -a $alignment_dir -b $bed_dir --rm_fastq $sample

# Merge reads into fragments
code/parse_bed.pl $bed_file.bed
sort -k 1,1 -k 2,2n -T $bed_dir/ ${bed_file}_edited.bed > ${bed_file}_sorted.bed

# Calcualte coverage
bedtools intersect -wao -sorted -a $master_ref -b ${bed_file}_sorted > ${bed_file}_temp.bed
awk 'OFS="\t" {print $4,$2,$3,$1,$13}' ${bed_file}_temp.bed | bedtools merge -scores sum -i - > ${bed_file}_coverage.bed
awk 'OFS="\t" { print $1, $4 / ($3 - $2 + 1)}' ${bed_file}_coverage.bed > ${bed_file}_read_depth.bed

rm ${bed_file}_temp.bed



