#!/usr/bin/env perl

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

my $exit_status;
if (! -d "fastq") { system("mkdir fastq"); } 
if (! -d "fastq/$sample") { system("mkdir fastq/$sample"); }
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

	if (-e fastq/$sample/$file)
	{
		system("rm fastq/$sample/$file");
	}

	$exit_status = system("cd fastq/$sample; wget --no-verbose $file_path");

	if ($exit_status != 0)
	{
		warn "problem downloading $file_path\n";
		warn "Exiting...";
		exit 1;
	}
	my $file_checksum = `md5sum fastq/$sample/$file`;
	chomp $file_checksum;
	$file_checksum =~ s/^([^ ]+?) (.+?)$/$1/;

	# For some reason the number of reads and the checksum do not match
	# what is listed in the sequence.index file (as of Sept 21, 2016)
	# We will disable the exit of the download script for now, but still
	# report an error when these discrepancies occur
	if ($file_checksum ne $checksum_ideal)
	{
		warn "Invaid checksum for $file_path\n";
		warn "should be $checksum_ideal, but is $file_checksum\n";
		exit 1;
	} else {
		print "checksum valid for $file_path\n";
	}
}
close(FASTQ);


