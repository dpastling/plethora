#!/usr/bin/env bash

genome=
first_read=
second_read=
bam_file=
max_insert=2000

while getopts g:b:i: opt; do
  case $opt in
  g)
      genome=$OPTARG
      ;;
  b)
      bam_file=$OPTARG
      ;;
  i)
      max_insert=$OPTARG
      ;;
  esac
done

shift $((OPTIND - 1))

first_read=$1
second_read=$2

if [[ -z $second_read ]]
then
	fastq_parameter="-U $first_read"
else
	fastq_parameter="-1 $first_read -2 $second_read"
fi


bowtie2 -p 12 --very-sensitive --minins 0 --maxins $max_insert -x $genome $fastq_parameter | samtools view -Sb - > $bam_file

