#!/usr/bin/env bash

bam=
pairing="paired"
reference_bed=
output=

while getopts r:p:b:o: opt; do
  case $opt in
  r)
      reference_bed=$OPTARG
      ;;
  p)
      pairing=$OPTARG
      ;;
  b)
      bam=$OPTARG
      ;;
  o)
      output=$OPTARG
      ;;
  esac
done

shift $((OPTIND - 1))

# manage other args here: $1, $2, etc.

if [ "$pairing" == "paired" ]
then
    samtools sort -n -@ 5 -m 5G $bam ${output}_sorted
    bedtools bamtobed -split -bedpe -i ${output}_sorted.bam > $output.bed
    code/parse_bed.pl $output.bed
elif [ "$pairing" == "single" ]
then
    bedtools bamtobed -i $bam > ${output}_edited.bed
else
    echo "Unknown pairing scheme"
    exit
fi
sort -k 1,1 -k 2,2n -T ./ ${output}_edited.bed > ${output}_sorted.bed
bedtools intersect -wao -sorted -a $reference_bed -b ${output}_sorted.bed > ${output}_temp.bed
awk 'OFS="\t" {print $4,$2,$3,$1,$13}' ${output}_temp.bed | bedtools merge -scores sum -i - > ${output}_coverage.bed
awk 'OFS="\t" { print $1, $4 / ($3 - $2 + 1)}' ${output}_coverage.bed > ${output}_read_depth.bed
if [ -f $output.bed ]
then
    rm ${output}_sorted.bam
    rm $output.bed
fi
rm ${output}_edited.bed
rm ${output}_temp.bed


