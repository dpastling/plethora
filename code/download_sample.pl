#!/usr/bin/perl

# This script downloads the fastq files for a given sample. 
# The user needs to supply the sample name and the sequence_index file

use strict;
use warnings;

if (!@ARGV)
{
	print "Usage:\t$0 <sample prefix> <sequence_index file>\n";
	exit;
}
my $sample = $ARGV[0];
my $sequence_index_file = $ARGV[1];
my $ftp_address = "ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3";

# Old hard coded files
#my $sequence_index_file = "sample_lists/1000Genomes_samples_needed.txt";
#my $sequence_index_file = "sample_lists/CLM_to_analyze_without_exome.txt";

my $exit_status;
if (! -d fastq) system("mkdir fastq"); 
if (! -d fastq/$sample) system("mkdir fastq/$sample");
open(FASTQ, $sequence_index_file) or die "cannot open the needed sequence index file: $sequence_index_file";
while(<FASTQ>)
{
	my $line = $_;
	chomp $line;
	my @attributes = split('\t', $line);
	next if ($attributes[0] eq "FASTQ_FILE");
	next if ($attributes[9] ne $sample);
	my $file_path = $attributes[0];
	my $file = $file_path;
	$file =~ s/^.+?\/([^\/]+)$/$1/;
	my $checksum_ideal  = $attributes[1];

	$exit_status = system("cd fastq/$sample; wget --no-verbose $ftp_address/$file_path");

	if ($exit_status != 0)
	{
		print STDERR "problem downloading $ftp_address/$file_path\n";
		print STDERR "Exiting...";
		exit 1;
	}
	my $file_checksum = `md5sum fastq/$sample/$file`;
	chomp $file_checksum;
	$file_checksum =~ s/^([^ ]+?) (.+?)$/$1/;
	if ($file_checksum ne $checksum_ideal)
	{
		print STDERR "Invaid checksum for $file_path\n";
		print STDERR "should be $checksum_ideal, but is $file_checksum\n";
		exit 1;
	}
}
close(FASTQ);


