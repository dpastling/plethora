#!/usr/bin/perl

use strict;
use warnings;
use Math::Complex;
use Math::Random;

if (!@ARGV)
{
 	print "Usage:\t$0 <one or more bed files>\n";
	exit;
}

# the inner distance is the distance between the reads
# (insert size - (2 * read length))
# the limit below is our criteria for considering a proper pair
my $max_inner_distance = 600;

random_set_seed_from_phrase(time);
my @distance;
foreach my $bed_file (@ARGV)
{
	next if ($bed_file !~ /\.bed$/);

	my $sufficient_number_of_reads = 50000000;
	
	## First we want to look at each proper pairs and determine the average distance between pairs
	open(INFILE, $bed_file) or die "cannot open $bed_file";
	while(<INFILE>)
	{
		my $line = $_;
		chomp $line;
		my @elements = split(/\t/, $line);

		if(isAProperPair(@elements))
		{
			my $d = $elements[4] - $elements[2];
			#next if ($d <= 0 || $d > 2500);
			push(@distance, $d);
		}
		last if ($#distance > $sufficient_number_of_reads);
	}
	close(INFILE);
	
	## Calculate the mean and standard deviation for later estimations
	## alternativly one could just sample a length from @distance
	## that way the actual distribtion would be reflected in the singlets
	
	my $mean_distance = 0;
	my $sd_distance = 0;
	for my $d (@distance)
	{
		$mean_distance += $d;
	}
	$mean_distance = $mean_distance / scalar(@distance);
	$mean_distance = sprintf("%.0f", $mean_distance);
	for my $d (@distance)
	{
		$d = $d - $mean_distance;
		$d = $d * $d;
		$sd_distance = $sd_distance + $d;
	}
	$sd_distance = $sd_distance / scalar(@distance);
	$sd_distance = sqrt($sd_distance);
	$sd_distance = sprintf("%.0f", $sd_distance);
	undef(@distance);
	
	# now that we know the actual inner distance and SD for our sample
	# set the max to five times the SD. This deals with bad alignments. 
	# A large distance can double or triple the coverage in troublesome 
	# regions with extra read ambiguity
	$max_inner_distance = $mean_distance + (5 * $sd_distance);
	
	## Now that we have figured out the distances, look at the file again
	## to parse the reads
	my $outfile = $bed_file;
	$outfile =~ s/.bed$/_edited.bed/;
	open(OUTFILE, ">$outfile") or die "cannot open $outfile";

	open(INFILE, $bed_file) or die "cannot open $bed_file";
	while(<INFILE>)
	{
		my $line = $_;
		chomp $line;
		my @elements = split(/\t/, $line);

		if (isAProperPair(@elements))
		{
			my $pos_min = min($elements[1], $elements[4]);
			my $pos_max = max($elements[2], $elements[5]);
			my $result = join("\t", $elements[0], $pos_min, $pos_max, @elements[6..8]);
			print OUTFILE "$result\n";
		} else
		{
			my @read1 = @elements[0..2,6..8];
			my @read2 = @elements[3..7,9];
			my $inner_distance = sprintf("%.0f", random_normal(1, $mean_distance, $sd_distance) / 2);
			# there may be cases where the inner-distance is less than zero (read overlap)
			# so don't bother trimming the read
			$inner_distance = 0 if ($inner_distance < 0);
			if ($read1[0] ne ".")
			{
				$read1[1] -= $inner_distance if ($elements[8] eq "-");
				$read1[2] += $inner_distance if ($elements[8] eq "+");
				$read1[1] = 0 if ($read1[1] < 0);
				my $result = join("\t", @read1);
				print OUTFILE "$result\n";
			}
			if ($read2[0] ne ".")
			{
				$read2[1] -= $inner_distance if ($elements[9] eq "-");
				$read2[2] += $inner_distance if ($elements[9] eq "+");
				$read2[1] = 0 if ($read2[1] < 0);
				my $result = join("\t", @read2);
				print OUTFILE "$result\n";
			}
		} 
	}
	close(INFILE);
	close(OUTFILE);
}


sub isAProperPair
{
	my @line = @_;
	# check that there is a valid alignment
	return(0) if ($line[0] eq ".");
	return(0) if ($line[3] eq ".");
	# check that the chromosomes match
	return(0) if ($line[0] ne $line[3]);
	# check that the reads are on opposite strands
	return(0) if ($line[8] eq $line[9]);
	# check inner distance
	return(0) if ($line[4] - $line[2] > $max_inner_distance);
	# let's consider overlapping reads as a proper pair
	return(1) if (($line[1] >= $line[4] && $line[1] <= $line[5]) || ($line[2] >= $line[4] && $line[2] <= $line[5])); 
	return(0) if ($line[1] > $line[4]);
	return(1);
}

sub max 
{
    my ($max, @vars) = @_;
    for (@vars) 
    {
        $max = $_ if $_ > $max;
    }
    return $max;
}

sub min 
{
    my ($min, @vars) = @_;
    for (@vars) 
    {
        $min = $_ if $_ < $min;
    }
    return $min;
}

