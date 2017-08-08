#!/usr/bin/env bash
#BSUB -J build
#BSUB -e logs/build_gc_model_%J.log
#BSUB -o logs/build_gc_model_%J.out
#BSUB -q normal
#BSUB -P plethora

# catch unset variables, non-zero exits in pipes and calls, enable x-trace.
set -o nounset -o pipefail -o errexit -x

bed=data/hg38_duf_canonical_v2.3.bed
genome=$HOME/genomes/bowtie2.2.9_indicies/hg38/hg38.fa

result=`echo $bed | sed 's/.bed//'`

bedtools getfasta -name -fi $genome -bed $bed -fo $result.fa

code/gc_from_fasta.pl $result.fa > ${result}_GC.txt

rm $result.fa


