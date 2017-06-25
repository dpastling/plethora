#!/usr/bin/perl
use strict;
use warnings;

# This script calculates the percent GC content from a fasta file
# Accepts a fasta file and returns the percent GC for each sequence in the file
# A fasta file for a set of genomic regions can be generated using `bedtools getfasta`

my %genome_size;
my %gc;
my $chr;

while(<>)
{
        my $line = $_;
        chomp $line;
        if ($line =~ /^>/)
        {
                $chr = $line;
                $chr =~ s/^>//;
                next;
        }
        $genome_size{$chr} += length($line);
        $line =~ s/[ATN]//g;
        $gc{$chr} += length($line);
}

foreach my $key (keys %genome_size)
{
        my $percent_gc = $gc{$key} / $genome_size{$key};
        print "$key\t$percent_gc\n";
}

