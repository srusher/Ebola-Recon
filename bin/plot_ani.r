library(ape)
library(reshape2)

args <- commandArgs(trailingOnly = TRUE)
input_file <- args[1]
output_file <- args[2]

ani = as.data.frame(read.table(file=input_file, sep="\t"))
sim = acast(ani, V1 ~ V2, value.var =  "V3", fill = 0)
dist = 100 - sim
tr = njs(dist)
tr$tip.label = basename(tr$tip.label)

pdf(output_file)
plot.phylo(tr)
dev.off()
