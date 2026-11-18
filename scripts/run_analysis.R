#!/usr/bin/env Rscript

find_root <- function(start) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  if (file.exists(path) && !dir.exists(path)) path <- dirname(path)
  repeat {
    if (file.exists(file.path(path, "sa_uta21_results.Rproj"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("Could not locate sa_uta21_results.Rproj.", call. = FALSE)
    path <- parent
  }
}
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else getwd()
script_path <- path.expand(script_path)
if (!grepl("^(/|[A-Za-z]:[/\\])", script_path)) script_path <- file.path(getwd(), script_path)
root <- find_root(script_path)
setwd(root)
source(file.path(root, "R", "analysis.R"), local = new.env(parent = globalenv()))
if (identical(Sys.getenv("UTA21_DATA_ONLY"), "true")) {
  cat("Data-only analysis complete; HTML report rendering was skipped.\n")
  quit(save = "no", status = 0)
}
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Install rmarkdown first: install.packages('rmarkdown')", call. = FALSE)
}
rmarkdown::render(file.path(root, "report", "uta21_analysis_report.Rmd"),
  output_dir = file.path(root, "output"), output_file = "uta21_analysis_report.html",
  quiet = TRUE, params = list(project_root = root), envir = new.env(parent = globalenv()))
cat("Report written to", file.path(root, "output", "uta21_analysis_report.html"), "\n")
