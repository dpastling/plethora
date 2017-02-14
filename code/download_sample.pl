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
my $max_tries = 10;

my $exit_status;
if (! -d "fastq") { system("mkdir fastq"); } 
if (! -d "fastq/$sample") { system("mkdir fastq/$sample"); }

my @ftp_path;
my @fastq_files;
my @checksums;
my @read_counts;

open(METADATA, $sequence_index_file) or die "cannot open the needed sequence index file: $sequence_index_file";
while(<METADATA>)
{
	my $line = $_;
	chomp $line;
	my @attributes = split('\t', $line);
	# TODO: read in first line and figure out proper column indicies
	next if ($attributes[0] eq "FASTQ_FILE");
	next if ($attributes[9] ne $sample);
	push @ftp_path, $attributes[0];
	my $file = $attributes[0];
	$file =~ s/^.+?\/([^\/]+)$/$1/;
	push @fastq_files, $file;
	push @checksums, $attributes[1];
	push @read_counts, $attributes[25];
}
close(METADATA);

my $number_of_tries = 0;
for (my $i = 0; $i <= $#fastq_files; $i++)
{
	my $file = $fastq_files[$i];
	if (-e "fastq/$sample/$file")
	{
		my $actual_checksum = `md5sum fastq/$sample/$file`;
		$actual_checksum = (split / /, $actual_checksum)[0];
		if ($actual_checksum eq $checksums[$i])
		{
			print "checksum valid for $sample/$file\n";
			next;
		}
		system("rm fastq/$sample/$file");
	}

	$exit_status = system("cd fastq/$sample; wget --no-verbose $ftp_path[$i]");

	if ($exit_status != 0)
	{
		warn "problem downloading $sample/$file\n";
		$number_of_tries++;
		if ($number_of_tries >= $max_tries)
		{
			warn "exceeded maximum number of tries: $max_tries\n";
			warn "Exiting...";
			exit 1;
		}
		$i = $i - 1;
		# remove any partially downloaded files
		# wget adds a digit to the end of the file if multiple attempts are made
		system("rm fastq/$sample/$file*");
		warn "retrying...\n";
		next;
	}

	# if multiple attempts have been made, wget will add a digit to the end of the 
	# file. We can save some download time by renaming the file with the highest digit.
	# If the file download is incomplete, it will be caught with the checksum below 
	if (-e "fastq/$sample/$file.1")
	{
	        my @retries = glob "fastq/$sample/$file.[1-9]*";
	        for (my $j = 0; $j <= $#retries; $j++)
	        {
	                $retries[$j] =~ s/fastq\/$sample\/$file\.//;
	        }
	        @retries = sort { $a <=> $b} @retries;
	        system("mv fastq/$sample/$file.$retries[$#retries] fastq/$sample/$file");
	        system("rm fastq/$sample/$file.[1-9]*");
	}

	my $file_checksum = `md5sum fastq/$sample/$file`;
	$file_checksum = (split / /, $file_checksum)[0];

	# sometimes the checksum in the sequence.index file does not match the actual
	# checksum. The metadata may be out of date. If this is the case comment out 
	# the section below or check the number of reads.
	if ($file_checksum ne $checksums[$i])
	{
		warn "Invaid checksum for $sample/$file\n";
		warn "should be $checksums[$i], but is $file_checksum\n";
		$number_of_tries++;
		if ($number_of_tries >= $max_tries)
		{
			warn "exceeded maximum number of tries: $max_tries\n";
			warn "Exiting...";
			exit 1;
		}
		$i = $i - 1;
		# remove any partially downloaded files
		# wget adds a digit to the end of the file if multiple attempts are made
		system("rm fastq/$sample/$file*");
		next;
	} else {
		print "checksum valid for $sample/$file\n";
	}
	$number_of_tries = 0;
}


