
options(stringsAsFactors = FALSE)

library(dplyr)
library(tidyr)

# load data
sequence.index <- read.delim("data/1000Genomes_samples_combined.txt")
trim.stats     <- read.delim("logs/trim_stats.txt", header = FALSE)
config_samples <- readLines("code/1000genomes/config.sh")
align.report   <- read.delim("align_report.txt", header = FALSE, sep = " ")


# tidy data
colnames(trim.stats) <- c("file", "type", "read.count")

colnames(align.report) <- c("SAMPLE_NAME", "aligned.fragments")
align.report <- mutate(align.report, SAMPLE_NAME = gsub("_sorted.bed", "", SAMPLE_NAME))

system('grep "correct number of reads" logs/clean_*.out | uniq > clean_report.txt')
clean.report   <- read.delim("clean_report.txt", header = FALSE)
clean.report   <- clean.report[, c(2,3)]
colnames(clean.report) <- c("SAMPLE_NAME", "file.type")

# duplicate entries are possible if the trim script failed and had to be rerun
# for these duplicates, take the most recent stats (largest row number)
trim.stats <- trim.stats %>% 
  mutate(row = 1:nrow(trim.stats)) %>%
  arrange(desc(row)) %>%
  filter(! duplicated(paste(file, type))) %>%
  arrange(row) %>%
  select(-row)

trim.stats <- trim.stats %>%
  mutate(file = gsub("^fastq/", "", file)) %>%
  separate(file, c("SAMPLE_NAME", "FASTQ_FILE"), sep = "/")

sequence.index <- mutate(sequence.index, FASTQ_FILE = gsub("^.+?/([^/]+.fastq.gz)$", "\\1", FASTQ_FILE))

# the sample names are stored in an array, one line per sample. grab all lines between "SAMPLES=(" and a closing bracket ")"
config_samples <- config_samples[(grep("SAMPLES", config_samples) + 1):length(config_samples)]
config_samples <- config_samples[1:(min(which(config_samples == ")")) - 1)]
config_samples <- data.frame(index = 1:length(config_samples), SAMPLE_NAME = config_samples)


# checks to perform:
#    - does the downloaded file have the correct number of reads?
#    - do we have the correct total number of reads for that sample?
#      if not we are missing some files
#    - remove the original files as long as the '*_filtered*' files exist

# QC measures:
#    - how many reads were lost due to quality filtering?
#    - do we have fewer than 100M reads for that sample?
#    - average number of bases trimmed if possible
#    - report metrics but do not delete any samples based on these metrics

trim.summary <- trim.stats %>% 
		  group_by(SAMPLE_NAME) %>% 
		  summarise(
		  total.reads = sum(read.count[type == "total"]), 
		  filtered.reads = sum(read.count[type == "discarded"]),
		  n.files = sum(type == "total")
		  ) %>%
		  mutate(
			  percent.filtered = filtered.reads / total.reads,
			  remaining.reads = total.reads - filtered.reads
		  )

meta.summary <- sequence.index %>%
			  group_by(SAMPLE_NAME, CENTER_NAME, POPULATION) %>%
			  summarise(
				  expected.reads = sum(READ_COUNT) / 2,
				  expected.files = n() / 2,
				  INSERT_SIZE = mean(INSERT_SIZE)
			  ) %>%
			  ungroup()

meta.summary <- left_join(meta.summary, config_samples, by = "SAMPLE_NAME")

trim.summary <- left_join(trim.summary, meta.summary, by = "SAMPLE_NAME")

align.report <- left_join(trim.summary, align.report, by = "SAMPLE_NAME")
align.report <- mutate(align.report, percent.aligned = aligned.fragments / remaining.reads)

flag.for.cleanup <- filter(trim.summary, n.files == expected.files, total.reads == expected.reads)

quality.problems <- filter(trim.summary, remaining.reads < 100e6 | percent.filtered > 0.1)

fastq.files = list.files("fastq", pattern = "_[12].fastq.gz$", recursive = TRUE, full.names = TRUE)
fastq.files = gsub("^fastq/", "", fastq.files)
fastq.files = data.frame(fastq.files)
fastq.files = separate(fastq.files, fastq.files, c("SAMPLE_NAME", "file"), sep = "/")
fastq.files = group_by(fastq.files, SAMPLE_NAME) %>% summarise(n.files = n() / 2)
fastq.files = left_join(fastq.files, meta.summary, by = "SAMPLE_NAME")
fastq.files = filter(fastq.files, n.files == expected.files)

align.files = list.files("alignments", pattern = ".bam")
align.files = gsub(".bam", "", align.files)

bed.files = list.files("results", pattern = ".bed")
bed.files = gsub("^([^_]+)_.+?.bed", "\\1", bed.files)
bed.files = unique(bed.files)

# grep "correct number of reads" logs/clean_*.out | uniq > clean_report.txt
# grep "something is wrong" logs/clean_*




finished.bams <- filter(clean.report, file.type == "bam")
finished.bams <- unique(finished.bams[["SAMPLE_NAME"]])

finished.beds <- filter(clean.report, file.type == "bed")
finished.beds <- unique(finished.beds[["SAMPLE_NAME"]])


sample.stage = meta.summary %>%
		mutate(stage = 0) %>%
		mutate(stage = ifelse(SAMPLE_NAME %in% fastq.files[["SAMPLE_NAME"]], 1, stage)) %>%
		mutate(stage = ifelse(SAMPLE_NAME %in% flag.for.cleanup[["SAMPLE_NAME"]], 2, stage)) %>%
		mutate(stage = ifelse(SAMPLE_NAME %in% finished.bams, 3, stage)) %>%
		mutate(stage = ifelse(SAMPLE_NAME %in% finished.beds, 4, stage)) %>%
		select(index, SAMPLE_NAME, stage) %>%
		filter(! is.na(index))


remove_fastq <- function(sample, pattern)
{
	old.files <- list.files(paste0("fastq/", sample), pattern = pattern, full.names = TRUE)
	if (length(old.files) > 0)
	{
		for (file in old.files)
		{
			system(paste("rm", file))
		}
	}
}

cleanup_old_files <- function(old.samples = flag.for.cleanup[["SAMPLE_NAME"]])
{
	for (sample in old.samples)
	{
		remove_fastq(sample, ".+?_[12].fastq.gz$")
		remove_fastq(sample, ".+?_orphans.fastq.gz$")
	}
}



cleanup_old_files()

write.table(sample.stage, file = "sample_stages.txt", sep = "\t", quote = FALSE, row.names = FALSE)

write.table(quality.problems, file = "quality_problems.txt", sep = "\t", quote = FALSE, row.names = FALSE)

write.table(align.report, file = "sequence_report.txt", sep = "\t", quote = FALSE, row.names = FALSE)


