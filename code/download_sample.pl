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
		next;
	}
	my $file_checksum = `md5sum fastq/$sample/$file`;
	chomp $file_checksum;
	$file_checksum =~ s/^([^ ]+?) (.+?)$/$1/;

	# sometimes the checksum in the sequence.index file does not match the actual
	# checksum. This may be due to an out of date index file. If this is the case
	# comment out the exit line below.
	if ($file_checksum ne $checksum_ideal)
	{
		warn "Invaid checksum for $file_path\n";
		warn "should be $checksum_ideal, but is $file_checksum\n";
		exit 1;
	} else {
		print "checksum valid for $file_path\n";
	}
}


