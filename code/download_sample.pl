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

my @fastq_files;
my @checksums;
my @read_counts;

open(METADATA, $sequence_index_file) or die "cannot open the needed sequence index file: $sequence_index_file";
while(<METADATA>)
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

}
close(<METADATA>);

my $number_of_tries = 0;
for (my $i = 0; $i <= $#fastq_files; $i++)
{
	my $file = $fastq_files[$i];
	if (-e "fastq/$sample/$file")
	{
		my $actual_checksum = `md5sum fastq/$sample/$file`;
		next if ($actual_checksum eq $checksums[$i]);
		system("rm fastq/$sample/$file");
	}

	$exit_status = system("cd fastq/$sample; wget --no-verbose $file_path");

	if ($exit_status != 0)
	{
		$number_of_tries++;
		if ($number_of_tries >= $max_tries)
		{
			warn "problem downloading $file_path\n";
			warn "exceeded maximum number of tries: $max_tries\n"
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


