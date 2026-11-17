#!/usr/bin/env Rscript

# Resolve the project root from the current directory or this script's location.
find_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  if (file.exists(path) && !dir.exists(path)) path <- dirname(path)
  repeat {
    if (file.exists(file.path(path, "sa_uta21_results.Rproj"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("Could not find sa_uta21_results.Rproj.")
    path <- parent
  }
}
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args[grep("^--file=", args)][1])
script_dir <- if (!is.na(script_arg) && nzchar(script_arg)) dirname(normalizePath(script_arg)) else getwd()
root <- find_root(script_dir)
setwd(root)
source(file.path(root, "R", "analysis.R"), local = new.env(parent = globalenv()))

# Render the report after the analysis has written all artifacts.
if (!requireNamespace("rmarkdown", quietly = TRUE)) stop("Install rmarkdown to render report/uta21_analysis_report.Rmd.")
rmarkdown::render(file.path(root, "report", "uta21_analysis_report.Rmd"),
                  output_dir = file.path(root, "output"),
                  output_file = "uta21_analysis_report.html", quiet = TRUE,
                  params = list(project_root = root),
                  envir = new.env(parent = globalenv()))
cat("Report written to", file.path(root, "output", "uta21_analysis_report.html"), "\n")
