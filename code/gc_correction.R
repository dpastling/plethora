
options(stringsAsFactors = FALSE)
library(dplyr)

args         <- commandArgs(trailingOnly = TRUE)

read.depth.file <- args[1]
gc.file         <- args[2]

output.file <- gsub("_read.depth.bed", "_gc_correct.txt", read.depth.file)

min.gc <- 0.2
max.gc <- 0.73

X <- read.delim(read.depth.file, header = FALSE)
colnames(X) <- c("domain", "coverage")
X <- as.tbl(X)

gc.data <- read.delim(gc.file, header = FALSE)
colnames(gc.data) <- c("domain", "percent.gc")

X <- inner_join(X, gc.data, by = "domain")

loess_fit <- function(x, y)
{
        fit <- loess(y ~ x)
        predict(fit)
}
X <- mutate(X, percent.gc = round(percent.gc, 2))

gc.model <- X %>%
	    filter(grepl("^((baseline)|(uc))", domain)) %>%
	    filter(percent.gc >= min.gc, percent.gc < max.gc) %>%
	    filter(coverage > 5e-2) %>%
	    mutate(coverage = log(coverage)) %>%
	    group_by(percent.gc) %>%
            summarise(coverage = mean(coverage)) %>%
            mutate(y.hat = loess_fit(percent.gc, coverage)) %>%
            mutate(k.gc = mean(coverage) / y.hat) %>%
	    select(-coverage, -y.hat) %>%
            ungroup()
X <- left_join(X, gc.model, by = c("percent.gc"))

# extend gc model for low and high gc regions
k.gc.min <- filter(gc.model, percent.gc == min(percent.gc))
k.gc.max <- filter(gc.model, percent.gc == max(percent.gc))
k.gc.min <- k.gc.min[["k.gc"]]
k.gc.max <- k.gc.max[["k.gc"]]
X <- mutate(X, k.gc = ifelse(percent.gc < min.gc, k.gc.min, k.gc))
X <- mutate(X, k.gc = ifelse(percent.gc >= max.gc, k.gc.max, k.gc))
X <- mutate(X, k.gc = ifelse(is.na(k.gc), 1, k.gc))

X <- mutate(X, corrected.coverage = log(coverage) * k.gc)
X <- mutate(X, corrected.coverage = exp(corrected.coverage))

haploid.coverage <- median(X[grep("^((baseline)|(uc))", X[["domain"]]), "corrected.coverage"]) / 2

X <- mutate(X, corrected.coverage = corrected.coverage / haploid.coverage)

write.table(X, output.file, sep = "\t", row.names = FALSE, quote = FALSE)

