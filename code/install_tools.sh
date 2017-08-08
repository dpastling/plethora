#!/usr/bin/env bash

# Install samtools
wget https://github.com/samtools/samtools/releases/download/1.3.1/samtools-1.3.1.tar.bz2
tar xvjf samtools-1.3.1.tar.bz2
cd samtools-1.3.1
make
make prefix=$HOME/bin/samtools-1.3.1 install
cd ../
rm samtools-1.3.1.tar.bz2
mv $HOME/bin/samtools-1.3.1/bin/* $HOME/samtools-1.3.1/
echo 'export PATH=$PATH:$HOME/bin/samtools-1.3.1' >> $HOME/.bashrc

# Install bedtools
wget https://github.com/arq5x/bedtools2/releases/download/v2.26.0/bedtools-2.26.0.tar.gz
cd bedtools2
make
make prefix=$HOME/bin/bedtools-2.26.0 install
rm -Rf bedtools2
rm bedtools-2.26.0.tar.gz 
mv $HOME/bin/bedtools-2.26.0/bin/* $HOME/bedtools-2.26.0/
echo 'export PATH=$PATH:$HOME/bin/bedtools-2.26.0' >> $HOME/.bashrc

# Install cutadapt
pip install --user --upgrade cutadapt

# Install Bowtie2
wget https://downloads.sourceforge.net/project/bowtie-bio/bowtie2/2.2.9/bowtie2-2.2.9-linux-x86_64.zip
unzip bowtie2-2.2.9-linux-x86_64.zip
mv bowtie2-2.2.9 $HOME/bin

# This should be added to your path
echo 'export PATH=$PATH:$HOME/bin/bowtie2-2.2.9' >> $HOME/.bashrc

# Download the prebuilt bowtie index
mkdir -p $HOME/genomes/bowtie-2.2.9/hg38
cd $HOME/genomes/bowtie-2.2.9/hg38
curl 'ftp://ftp.ncbi.nlm.nih.gov/genomes/archive/old_genbank/Eukaryotes/vertebrates_mammals/Homo_sapiens/GRCh38/seqs_for_alignment_pipelines/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index.tar.gz' -o hg38.tar.gz
for x in GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index*
do
	new=`echo $x | sed 's/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bowtie_index/hg38/'`
	mv $x $new
done

# Use bowtie2-instpect to convert the index into a fasta
bowtie2-inspect -a $HOME/genomes/bowtie-2.2.9/hg38 > hg38.fa

# Install perl modules
cpan App::cpanminus
cpanm Math::Random
cpanm Math::Complex

# Alternativly the perl modules can be installed this way
#perl -MCPAN -e 'install Math::Random'
#perl -MCPAN -e 'install Math::Complex'


