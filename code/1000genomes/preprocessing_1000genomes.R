options(stringsAsFactors = F)

library(data.table)
library(dplyr)
library(dtplyr)

# the desired number of samples per population
pop.quota <- 25

################################################################
# Download sample metadata
################################################################
ebi.base.path <- "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/"
ebi.file.path <- "1000_genomes_project/1000genomes.sequence.index"

ncbi.path <- "ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/sequence.index"

# Note: The first 28 lines contain comments using a double hash '^##'. 
#       The header row contains a single hash. I wish there was a way 
#       to ignore lines with the double hash an not the single hash
# Also note: due to import problems, read everything in as character
sequence.index <- fread(
	paste0(ebi.base.path, ebi.file.path), 
	skip = 28, 
	colClasses = "character"
	)

# ignore samples that have failed QC in the past
failed.samples  <- read.delim("data/failed_samples.txt", header = FALSE)
failed.samples  <- failed.samples[[1]]


# The following are the samples processed in:
# Sudmant, P. H., et al. (2010). Diversity of human copy number variation
# and multicopy genes. Science, 330(6004), 641–646.
# http://doi.org/10.1126/science.1197005
sudmant.samples <- read.delim("data/sudmant_samples.txt", header = FALSE)
sudmant.samples <- sudmant.samples[[1]]

# The Sikela lab has DNA for the following samples. We will give
# these priority
dna.samples     <- read.delim("data/CLM_DNA_sample_names.txt", header = FALSE)
dna.samples     <- dna.samples[[1]]

irys.samples    <- read.delim("data/rd-irys-samples.txt", header = FALSE)
irys.samples    <- irys.samples[[1]]

failed.samples  <- read.delim("data/failed_samples.txt", header = FALSE)
failed.samples  <- failed.samples[[1]]

################################################################
# Cleanup
################################################################
# the header row starts with a '#'
colnames(sequence.index)[1] <- gsub("#", "", colnames(sequence.index)[1])

# set column names so the are consistant between NCBI and EBI
colnames(sequence.index) <- gsub("FASTQ_ENA_PATH", "FASTQ_FILE", colnames(sequence.index))


################################################################
# Filter files
################################################################
sequence.index <- sequence.index %>% 
    filter(
        grepl("HiSeq", INSTRUMENT_MODEL),
		INSTRUMENT_PLATFORM == "ILLUMINA",
        LIBRARY_LAYOUT == "PAIRED",
        WITHDRAWN == 0,
        ! grepl("exome", STUDY_NAME, ignore.case = TRUE)
    )

sample.stats <- sequence.index %>% 
                filter(grepl("_2.(filt.)*fastq.gz", FASTQ_FILE)) %>%
                group_by(SAMPLE_NAME, CENTER_NAME, LIBRARY_NAME) %>% 
                summarize(
                    n.files = n(), 
                    n.reads = sum(as.numeric(READ_COUNT)), 
                    mean.insert.size = mean(as.numeric(INSERT_SIZE)), 
                    pop = unique(POPULATION)
                ) %>%
                ungroup()


# for samples with insert.size of zero, impute with mean insert size for that center (there are seven samples like this from WUGSC)

# 10x coverage is 100 million reads for an insert size of 300bp
# the size of the human genome is 3.235e9 bp
sample.stats <- mutate(sample.stats, coverage = (n.reads * mean.insert.size) / 3.235e9)
sample.stats <- filter(sample.stats, coverage > 10, n.reads < 400e6)
sample.stats <- filter(sample.stats, ! SAMPLE_NAME %in% failed.samples)


# Some samples were sequenced independantly by multiple centers
# give priority to c("BGI", "SC", "ILLUMINA", "MPIMG", "WUGSC")
# - The libraries from BCM had a short insert size. 
# - The libraries from BI had low overall qualities (relative to the rest). 
# - Prioritize the other over BCM and BI
# - prioritize BCM over BI
# - choose samples with higher coverage 
sample.stats <- as.data.frame(sample.stats)
sample.stats <- mutate(sample.stats, 
                  center.rank = as.numeric(factor(CENTER_NAME, 
                  levels = c("BGI", "SC", "ILLUMINA", "MPIMG", "WUGSC", 
                  "BCM", "BI"))))
# the order of the first five centers doesn't matter
sample.stats <- mutate(sample.stats, center.rank = 
                    ifelse(center.rank < 6, 1, center.rank))
sample.stats <- group_by(sample.stats, SAMPLE_NAME) %>%
                arrange(center.rank, desc(n.reads)) %>%
                mutate(file.rank = 1:n()) %>%
                filter(file.rank == 1) %>%
                ungroup()


################################################################
# Narrow list
################################################################
# After filtering, we have more than a thousand samples for processing.
# This is too much data to store at once, and will take much too long 
# to process. We need to reduce this list into something much more 
# manageable. Let's select all samples processed by Sudmant and those
# for which we have DNA. Then for the remaining samples, choose 25 or
# 30 from each population. 

# Note: in the final analysis, it is important to select an even number
# of samples from each population so that the mean and variance are
# reflective of the human population

samples.of.interest     <- c(sudmant.samples, dna.samples, irys.samples)
populations.of.interest <- c("MXL", "CLM", "PUR", "ASW", "LWK", "YRI", 
                             "JPT", "CHB", "CHS", "TSI", "CEU", "IBS", 
                             "FIN", "GBR")

# 10x coverage is 100 million reads for 300bp fragments
#sample.stats <- filter(sample.stats, n.reads >= 100e6, n.reads < 400e6)
sample.stats <- mutate(sample.stats, coverage = (n.reads * mean.insert.size) / 3.235e9)
# we want the unfiltered coverage to be 12 so allow for up to 10% of the reads to be trimmed
sample.stats <- filter(sample.stats, coverage >= 12, n.reads >= 90e6, n.reads < 400e6)
sample.stats <- filter(sample.stats, ! SAMPLE_NAME %in% failed.samples)




sample.stats <- filter(sample.stats, ! SAMPLE_NAME %in% failed.samples)

sequence.index <- filter(sequence.index, 
    paste(SAMPLE_NAME, CENTER_NAME, LIBRARY_NAME) %in% 
    paste(sample.stats[["SAMPLE_NAME"]], sample.stats[["CENTER_NAME"]],
    sample.stats[["LIBRARY_NAME"]]))


desired.samples <- filter(sequence.index, SAMPLE_NAME %in% samples.of.interest )
sample.stats    <- filter(sample.stats, ! SAMPLE_NAME %in% samples.of.interest )

# limit our analysis to these populations
sample.stats <- filter(sample.stats, pop %in% populations.of.interest)


# the desired samples fills our quota for some populations. 
# let's figure out which populations those are and remove
# them from further consideration
sample.count <- desired.samples %>%
                  group_by(POPULATION) %>% 
                  summarise(n = length(unique(SAMPLE_NAME)))
filled.quota <- filter(sample.count, n >= pop.quota)
filled.quota <- filled.quota[["POPULATION"]]
sample.stats <- filter(sample.stats, ! pop %in% filled.quota)

# let's re-rank the remaining samples by the criteria mentioned above and
# prioritize high coverage/quality samples over the others.
sample.stats   <- sample.stats %>% 
                  filter(SAMPLE_NAME %in% sequence.index[["SAMPLE_NAME"]]) %>%
                  group_by(pop) %>%
                  arrange(center.rank, desc(n.reads))

needed.samples <- filter(sample.count, n < pop.quota)
for (p in needed.samples[["POPULATION"]])
{
    n <- filter(needed.samples, POPULATION == p)
    n <- abs(n[["n"]] - pop.quota)
    s <- filter(sample.stats, pop == p)
    s <- s[["SAMPLE_NAME"]]
    if (length(s) < n) n <- length(s)
    s <- s[1:n]
    X <- filter(sequence.index, SAMPLE_NAME %in% s)
    desired.samples <- bind_rows(desired.samples, X)
    sample.stats  <- filter(sample.stats, pop != p)
}


for (p in unique(sample.stats[["pop"]]))
{
    n <- pop.quota
    s <- filter(sample.stats, pop == p)
    s <- s[["SAMPLE_NAME"]]
    if (length(s) < n) n <- length(s)
	s <- s[1:n]
    X <- filter(sequence.index, SAMPLE_NAME %in% s)
    desired.samples <- bind_rows(desired.samples, X)
}

date.stamp <- as.Date(Sys.time())

write.table(desired.samples, file = paste0("data/1000Genomes_samples_", date.stamp ,".txt", sep = "\t", quote = FALSE, row.names = FALSE)


