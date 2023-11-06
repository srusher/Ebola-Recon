#!/usr/bin/env R --vanilla

if (!requireNamespace(c("ape", "reshape2"), quietly = TRUE)) {
  install.packages(c("ape", "reshape2"), repos = "https://cran.r-project.org")
  library(ape)
  library(reshape2)
}


