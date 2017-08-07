
# plethora

Plethora is a tool kit for copy number variation (CNV) analysis of highly
duplicated regions.  It was tailored specifically for the DUF1220 domain which
is found in over 300 copies in the human genome. However it could be applied to
other high copy domains and segmental duplications. The details will be
published in the forthcoming paper:

> Astling, DP, Heft IE, Jones, KL, Sikela, JM. "High resolution measurement of
> DUF1220 domain copy number from whole genome sequence data" (2017) BMC
> Genomics. under review

## Dependencies

Plethora depends on the following software. Note that updates to samtools and
bedtools may break plethora due to changes with the parameters

- bowtie2 version 2.2.9
- bedtools version 2.17.0
- samtools version: 0.1.19-44428cd
- cutadapt v1.12
- Perl module: Math::Random
- Perl module: Math::Complex

You will also need to download the human genome hg38 and build a bowtie index
for it. Instructions for doing this can be found on the Bowtie2 website.


## Quick Start

The following illustrates the minimal steps necessary to run the pipeline. The simulated sequence data are for a single DUF1220 domain, so this should run very quickly relative to a full WGS data set. The following code can also be used to test that your environment has been set up correctly and that the installed software is working.

1. Create directories for the resulting files (if they don't exist already)

    mkdir alignments
    mkdir results

2. Trim low quality bases from the 3' ends of the reads and remove any that are shorter than 80bp. Since we are working with simulated reads, we don't expect many reads to be effected by this.

    cutadapt \
    -a XXX -A XXX -q 10 --minimum-length 80 --trim-n \
    -o fastq/test_1_filtered.fastq.gz \
    -p fastq/test_2_filtered.fastq.gz \
    fastq/test_1.fastq.gz \
    fastq/test_2.fastq.gz


3. Align reads to the genome with Bowtie2. Note you may have to change the path to point to your Bowtie2 reference

    code/bowtie2.sh \
    -g $HOME/genomes/bowtie2.2.9_indicies/hg38/hg38 \
    -b alignments/test.bam \
    fastq/test_1_filtered.fastq.gz \
    fastq/test_2_filtered.fastq.gz

4. Calculate coverage for each DUF1220 domain

    code/make_bed.sh \
    -r data/hg38_duf_full_domains_v2.3.bed \
    -p "paired" \
    -b alignments/test.bam \
    -o results/test

The resulting file ??? has the coverage for each domain. The reads were
simulated from NBPF1\_CON1\_1 at 30x coverage. Bases on prior work, we expect to
find that most reads align to NBPF1\_CON1\_1, but some reads will map to one of
the other CON1 domains of NBPF1 or to NBPF1L.

View the results:

    ls -ltr results

example output here

    awk '$?? > 0' results/???

example output here




## Processing sequence data from the 1000 Genomes Project

The following describes how to apply plethora to the 1000 Genomes data and
describes the main steps in a little more detail. The scripts for processing the
1000 Genomes data can be found in the `code/1000genomes` folder. These scripts
are for submitting jobs to the LSF job queuing system for parallelizing the
processing of multiple samples. These scripts can be modified for submitting to
other job queuing systems such as PBS or Slurm. Alternatively the scripts in the main `code` folder
can be run individually without a job scheduler as described above.

If everything has been configured correctly, you should be able to process the
entire dataset with the following command:

    bsub < code/1000genomes/run.sh

However, it is likely that some jobs will fail at various stages due to
networking issues or from heavy usage of your cluster. So you may have to submit
some of the steps to the queue separately.


#### config.sh

The config file is where all the project specific parameters and sample names
should go. The other scripts should be as abstract as possible for reuse. 

Here are few important variables for the pipeline:

- **sample_index** path to the file with the 1000 Genomes information
- **genome** path to the bowtie indices for genome
- **master_ref** path to the bedfile with the DUF1220 coordinates, or other
  regions of interest
- **alignment_dir** path to where the bowtie alignments will go
- **result_folder** path to where the resulting coverage files will be stored
- **bowtie_params** additional parameters to be passed to bowtie2 that are
  specific to the project

The config file will also create directories where all the results will go.


### 1\_download.sh

    bsub < code/1000genomes/1_download.sh

This script downloads the fastq files for each sample from the 1000
Genomes site as specified in a sample\_index file. The script fetches all associated files with a given sample name and uses `wget` to download the files to the `fastq` folder. The script checks the md5sum hashes for each file against the
downloaded file. The script exits with an error if they do not match.

Alternativly, if you are not using the LSF queuing system, the script can be run manually like so:

    code/download_fastq.pl HG00250 data/1000Genomes_samples.txt 

### 2\_trim.sh

    bsub < code/1000genomes/2_trim.sh

This script automates the read trimming by Cutadapt. Cutadapt could be directly as described in the Quick Start guide above.

### 3\_batch\_bowtie.sh

    bsub < code/1000genomes/3_batch_bowtie.sh

This script automates the Bowtie2 alignments for the filtered reads generated above.

Alterativly, the 


### 4\_batch\_clean.sh

    bsub < code/1000genomes/4_batch_clean.sh

This script removes intermediate files after the alignment or bed files are created. It first confirms that files from previous steps have been run correctly before removing them. 

By default it assumes that the number of reads in the fastq file is
correct (verified via checksum or read counting). Optionally you can provide a
file with the expected number of reads. The script deletes the file from a
prior step if the file in the next step has the correct number of reads (e.g.
deleted the original bam file if the sorted bam has the correct number of
reads).

If files have been downloaded from a public repository like the 1000 Genomes, this script can remove the fastq files by passing an optional flag.

The script assumes the `.bam` file contains unaligned reads (e.g. the number of reads in the fastq file should match the number of reads in the .bam file).

Behind the scenes the clean script runs `code/clean_files.pl`. For more information on how to run this directly:

    code/clean_files.pl -h


### 5\_make\_bed.sh

This script: 

1. Coverts the .bam alignment file into bed format
2. Parses the reads
3. Calls the `merge_pairs.pl` script (described below) to combined proper pairs into a single
fragment
4. Finds overlaps with the reference bed file containing the regions of interest
(e.g. DUF1220)
5. Calculates the average coverage for each region: (number of bases that
overlap) / (domain length)

### 6\_batch\_clean.sh

This script is a link to the script above. At this stage it will remove the alignment and fastq files if present.


### 7\_batch\_gc\_correction.R

    bsub < code/1000genomes/7_batch_gc_correction.sh

This script performs the GC correction step using conserved regions that are
assumed to be found in diploid copy number. This script requires the `_read.depth.bed` file generated in step five above as well as a file with the percent GC content for each domain.

Behind the scenes, the shell script calls `code/gc_correction.R` which can be run manually like so:

    code/gc_correction.R results/HG00250_read.depth.bed data/hg38_duf_full_domains_v2.3_GC.txt


## Other useful scripts

### preprocessing\_1000genomes.R

### build\_gc\_model.sh

### gc\_from\_fasta.pl

### merge\_pairs.pl

This is a helper script to `make_bed.sh` that combines proper pairs into a
single fragment, and separates discordant pairs into single end reads. The
lengths of the single end reads are extended by half the mean fragment size,
which is determined from the data itself. The extended length is sampled from a
normal distribution using the mean and standard deviation of the measured fragment sizes.





