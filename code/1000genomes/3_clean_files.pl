#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure("bundling");

my $help;
my $delete_fastq;
my $manifest;
my $fastq_folder = "./fastq";
my $align_folder = "./alignments";
my $bed_folder = "./results";

GetOptions (    "h|help"	   => \$help,
				"f|fastq=s"    => \$fastq_folder,
				"a|align=s"    => \$align_folder,
				"b|bed=s"      => \$bed_folder,
				"d|rm_fastq"   => \$delete_fastq,
				"m|manifest=s" => \$manifest
           );

if (!@ARGV || @ARGV > 1 || $help || ! ($fastq_folder || $align_folder || $bed_folder))
{
	print "$0:  clean up intermediate files after converting alignment to .bed format\n";
	print "\n";
	print "By default it assumes that the number of reads in the fastq file is\n";
	print "correct (verified via checksum or read counting). Optionally you can provide a\n";
	print "file with the expected number of reads. The script deletes the file from a\n";
	print "prior step if the file in the next step has the correct number of reads (e.g.\n";
	print "deleted the original bam file if the sorted bam has the correct number of\n";
	print "reads).\n";
	print "\n";
	print "If files have been downloaded from a public repository like the 1000 Genomes,\n";
	print "this script can remove the fastq files by passing an optional flag.\n";
	print "\n";
	print "assume bam contains unaligned reads\n";
	print "--------------------------------------------------\n";
	print "Usage:\t$0 [options] <sample name> \n";
	print "\n";
	print "Options:\n";
	print "    -f/fastq <path>         path to .fastq files             default: ./fastq\n";
	print "    -a/align <path>         path to .bam files               default: ./alignments\n";
	print "    -b/bed <path>           path to .bed files               default: ./results\n";
	print "    -d/rm_fastq             remove fastq files               default: keep fastq files\n";
	print "    -m/manifest <filename>  sequence_index file from         default: none\n";
	print "                            the 1000 Genomes project\n";
	print "    -h                      print this help message and quit\n";
	print "\n";
	exit;
}

my $sample_name = $ARGV[0];
my $expected_number_of_reads = 0;
my $fastq_count;
my $align_count;
my $sorted_align_count;
my $bed_count;
my $pairing;

# We assume the files follow this naming convention
my $bam_file        = "$align_folder/$sample_name.bam";
my $sorted_bam_file = "$align_folder/$sample_name\_sorted.bam";
my $bed_file        = "$bed_folder/$sample_name.bed";


my @first_pair;
my @second_pair;
my @fastq_files;
if ($manifest)
{
	open(META, $manifest) or die "cannot open $manifest";
	while(<META>)
	{
		my $line = $_;
		chomp $line;
		my @data = split('\t', $line);
		next if ($data[0] eq "FASTQ_FILE");
		next if ($data[9] ne $sample_name);
		my $file_path = $data[0];
		my $file = $file_path;
		$file =~ s/^.+?\/([^\/]+)$/$1/;
		$file = "fastq/$sample_name/$file";
		if ($file =~ /_1.filt.fastq.gz/)
		{
			push @first_pair, $file;
		} elsif ($file =~ /_2.filt.fastq.gz/)
		{
			push @second_pair, $file;
		} else 
		{
			next;
		}
		# note both pairs will be present in alignment file
		# so we need to count both
		$expected_number_of_reads += $data[23];
	}
	close(META);
	if (! $expected_number_of_reads)
	{
		warn "could not find sample $sample_name in the manifest file $manifest\n";
		exit 1;
	}
	@fastq_files = (@first_pair, @second_pair);
}

if ($fastq_folder)
{
	if (! $manifest)
	{
		@fastq_files = glob "$fastq_folder/$sample_name/*.fastq.gz";
		if (! @fastq_files)
		{
			@fastq_files = glob "$fastq_folder/$sample_name/*.fastq";
		} 
	}
	foreach my $file (@fastq_files)
	{
		$fastq_count += count_fastq($file);
		if ($file =~ /_2.filt.fastq.*/)
		{
			$pairing = "paired";
		} else
		{
			$pairing = "single";
		}
	}
	if (! $manifest)
	{
		$expected_number_of_reads = $fastq_count;
	}
	if ($fastq_count != $expected_number_of_reads)
	{
		warn "something is wrong with the fastq file(s) for sample $sample_name!\n";
		warn "expected $expected_number_of_reads reads and counted $fastq_count reads\n";
		exit 1;
	}
}


if ($align_folder && -f $bam_file)
{
	$align_count = `samtools view -c $bam_file`;
	chomp $align_count;
	if (! $expected_number_of_reads)
	{
		$expected_number_of_reads = $align_count;
	} 
	if ($align_count != $expected_number_of_reads) {
		warn "something is wrong with the .bam file: $bam_file!\n";
		warn "expected $expected_number_of_reads reads and counted $align_count reads\n";
		exit 1;
	}
	if ($delete_fastq && $align_count == $expected_number_of_reads)
	{
		foreach my $file (@fastq_files)
		{
			system("rm $file");
		}
	}
}

if ($align_folder && -f $sorted_bam_file)
{
	$sorted_align_count = `samtools view -c $sorted_bam_file`;
	if (! $expected_number_of_reads)
	{
		$expected_number_of_reads = $sorted_align_count;
	} 
	if ($sorted_align_count != $expected_number_of_reads) {
		warn "something is wrong with the sorted .bam file: $sorted_bam_file!\n";
		warn "expected $expected_number_of_reads reads and counted $sorted_align_count reads\n";
		exit 1;
	}
	if (-f "$bam_file" && $sorted_align_count == $expected_number_of_reads)
	{
		system("rm $bam_file");
	}
}

if ($bed_folder && -f $bed_file)
{
	if (! $expected_number_of_reads)
	{
		warn "no files to be processed\n";
		exit 1;
	}
	if (! $pairing)
	{
		my $file;
		if (-f $sorted_bam_file) 
		{
			$file = $sorted_bam_file;
		} elsif (-f $bam_file) 
		{
			$file = $bam_file;
		}
		$pairing = `samtools view -f 0x0001 $file | head -n 1 | cut -f 1`;
		$pairing = "paired" if ($pairing);
	}
	if ($pairing eq "paired") 
	{
		$expected_number_of_reads = $expected_number_of_reads / 2;
	}
	$bed_count = `cat $bed_file | wc -l`;
	chomp $bed_count;
	if ($bed_count != $expected_number_of_reads) {
		warn "something is wrong with the .bed file: $bed_file!\n";
		warn "expected $expected_number_of_reads reads and counted $bed_count reads\n";
		exit 1;
	}
	if ($delete_fastq && @fastq_files && $bed_count == $expected_number_of_reads)
	{
		foreach my $file (@fastq_files)
		{
			system("rm $file") if (-f $file);
		}
	}
	if (-f $bam_file && $bed_count == $expected_number_of_reads)
	{
		system("rm $bam_file");
	}
	if (-f $sorted_bam_file && $bed_count == $expected_number_of_reads)
	{
		system("rm $sorted_bam_file");
	}
}


sub count_fastq
{
	my $file = shift;
	if (! -f $file)
	{
		print "cannot open the fastq file: $file\n";
		exit 1;
	}
	my $count;
	if ($file =~ /\.gz$/)
	{
		$count = `gunzip -c $file | paste - - - - | wc -l`;
	} else {
		$count = `cat $file | paste - - - - | wc -l`;
	}
	chomp $count;
	return $count;	
}
