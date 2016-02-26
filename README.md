
# CNV Pipeline

This CNV Pipeline is for the estimating the number of DUF1220 copies from whole genome sequencing. The details will be published in the fourthcoming paper:

> Astling, DP, Heft IE, Jones, KL, Sikela, JM. "High resolution measurement of DUF1220 domain copy number from whole genome sequence data"

### config file

The config file is where all the project specific parameters and sample names should go. The other scripts should be as abstract as possible for reuse. 

Here are few important variables for the pipeline:

- **sample_index** path to the file with the 1000 Genomes information
- **genome** path to the bowtie indicies for genome
- **master_ref** path to the bedfile with the DUF1220 coordinates, or other regions of interest
- **alignment_dir** path to where the bowtie alignments will go
- **result_folder** path to where the resulting converage files will be stored
- **bowtie_params** addional parameters to be passed to bowtie2 that are specific to the project

### download_fastq.pl

    code/download_fastq.pl HG00250 data/1000Genomes_samples_needed.txt 

This script downloads the fastq files for a particular sample from the 1000 Genomes site as specified in a sample_index file. The script fetches the filenames from the sample_index file and downloads the files to the fastq folder using `wget`. The script checks the md5sum hashes for each file against the downloaded file. The script exits with an error if they do not match.

### batch_bowtie2.sh

This script submits jobs to the LSF queuing system and runs both the downloading of the fastq files and aligns them to the genome

