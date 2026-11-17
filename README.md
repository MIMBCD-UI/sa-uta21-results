# UTA21 evaluation analysis

This R project scores the included SUS, adapted NASA-TLX, and Trust in Automation (TiA) responses, compares C1 and C2 within participant, summarizes task time and assistant-participant BI-RADS agreement, and describes condition-order patterns. It produces a rendered HTML report, publication-ready PNG figures, and CSV summary tables from the source data.

## Run from the project root

Install the project dependencies once:

```r
install.packages(c("ggplot2", "rmarkdown", "knitr"))
```

Then run:

```sh
Rscript scripts/run_analysis.R
```

The command creates `output/uta21_analysis_report.html`, `output/figures/`, and `output/tables/`. Open the HTML file in a browser. You can also open `sa_uta21_results.Rproj` in RStudio and run `scripts/run_analysis.R`.

The project root is located from the runner script, so the command also works when called from another working directory:

```sh
Rscript /path/to/sa-uta21-results/scripts/run_analysis.R
```

## Project layout

```text
R/analysis.R                      Data checks, score calculations, statistics, tables, and plots
scripts/run_analysis.R            Root-aware entry point and report renderer
report/uta21_analysis_report.Rmd   Narrative HTML report
data/                              Included UTA21 source CSV files
output/figures/                    Appendix-ready charts
output/tables/                     Analysis tables in CSV format
```

The provenance CSV is retained as source documentation and is not used to derive the participant outcome summaries.

## Scoring and analysis conventions

- C1 is Clinical-First; C2 is Regulatory-First. Differences are C2 minus C1.
- SUS is scored with the standard alternating positive/negative item key and scaled to 0–100.
- Adapted NASA-TLX is the unweighted mean of six 1–10 items; the performance item is reversed as `11 - response`.
- TiA subscales use the existing Koerber item mapping in the analysis script; items 5, 7, 10, 15, and 16 are reversed as `6 - response`.
- Questionnaire tests are paired by participant. The report includes paired t confidence intervals, Cohen's dz, and Wilcoxon signed-rank p-values. The sample is small; inferential results are exploratory, and no multiplicity adjustment is applied.
- Time on task is summarized per case and compared across conditions using each participant's condition mean. Figures also show case-level distributions by experience and observed block.
- Exact BI-RADS agreement requires equal numeric categories. Suspicion bands are Low (1–2), Moderate (3–4), and High (5). Band agreement excludes participant BI-RADS 0 because it cannot be assigned to a band; exact agreement keeps 0 as a valid numeric response.
- Block order follows row order in the case CSV: a participant's first three rows are treated as the first block. Treat order effects as descriptive.

## Reproducibility notes

The project uses base R for data handling and statistical calculations, with `ggplot2` for figures and `rmarkdown`/`knitr` for the report. The current data have eight participants and 48 case observations. No data are downloaded or modified by the analysis. Package installation is a one-time setup step; no lockfile is currently included.
