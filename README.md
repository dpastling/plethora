
# plethora

Plethora is a tool kit for estimating copy number of highly duplicated regions.
It was tailored specifically for the DUF1220 domain which is found in over 300
copies in the human genome. However it could be applied to other high copy
domains and segmental duplications. The details will be published in the
forthcoming paper:

> Astling, DP, Heft IE, Jones, KL, Sikela, JM. "High resolution measurement of
> DUF1220 domain copy number from whole genome sequence data"

## Dependancies

Plethora depends on the following software. Note that updates to samtools and
bedtools may break plethora due to changes with the parameters

- bowtie2 version 2.2.9
- bedtools version 2.17.0
- samtools version: 0.1.19-44428cd

You will also need to download the human genome hg38 and build a bowtie index
for it. Instructions for doing this can be found on the bowtie website.

## Geting Started

A set of scripts for processing the 1000 Genomes data can be found in the
`code/1000genomes` folder


### config.sh

The config file is where all the project specific parameters and sample names
should go. The other scripts should be as abstract as possible for reuse. 

Here are few important variables for the pipeline:

- **sample_index** path to the file with the 1000 Genomes information
- **genome** path to the bowtie indicies for genome
- **master_ref** path to the bedfile with the DUF1220 coordinates, or other
  regions of interest
- **alignment_dir** path to where the bowtie alignments will go
- **result_folder** path to where the resulting converage files will be stored
- **bowtie_params** addional parameters to be passed to bowtie2 that are
  specific to the project

### download_fastq.pl

    code/download_fastq.pl HG00250 data/1000Genomes_samples_needed.txt 

This script downloads the fastq files for a particular sample from the 1000
Genomes site as specified in a sample_index file. The script fetches the
filenames from the sample_index file and downloads the files to the fastq folder
using `wget`. The script checks the md5sum hashes for each file against the
downloaded file. The script exits with an error if they do not match.

### batch_bowtie2.sh

This script submits jobs to the LSF queuing system and runs both the downloading
of the fastq files and aligns them to the genome. It can be submitted to the
queue like so:

    bsub < code/batch_bowtie2.sh

