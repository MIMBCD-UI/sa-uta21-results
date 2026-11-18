# UTA21 evaluation analysis

A reproducible R project for scoring the included UTA21 questionnaire data, comparing C1 and C2 within participant, summarizing task time and assistant-participant BI-RADS agreement, and describing condition-order patterns.

## Run

Install the two project dependencies once:

```r
install.packages(c("ggplot2", "rmarkdown"))
```

From the project root, run:

```sh
Rscript scripts/run_analysis.R
```

For table generation without HTML rendering (for example, on a machine without `ggplot2`/`rmarkdown`), run `UTA21_DATA_ONLY=true Rscript scripts/run_analysis.R`. This mode writes primary and supplementary CSV tables only.

The runner also works when called by absolute path from another directory. It writes the report to `output/uta21_analysis_report.html`, figures to `output/figures/`, and CSV tables to `output/tables/`.

## Project layout

- `R/analysis.R`: reads and validates source CSVs, scores measures, computes statistics, writes tables and figures.
- `R/advanced_analysis.R`: supplementary participant-level bootstrap/multiplicity analysis, matched case-time sensitivity, and agreement weighting/repeat sensitivities. Its outputs are separate from the established primary outputs.
- `scripts/run_analysis.R`: locates the project root, runs the analysis, and renders the report.
- `report/uta21_analysis_report.Rmd`: narrative report sourced from the generated outputs.
- `data/`: included case, questionnaire, and case-provenance CSVs.
- `output/`: generated HTML report, figures, and summary tables.

## Analysis conventions

- C1 is Clinical-First; C2 is Regulatory-First. Paired differences are C2 minus C1.
- SUS uses the standard alternating item key and 0–100 transformation.
- The adapted NASA-TLX is the unweighted mean of six 1–10 items, with performance reversed as `11 - response`.
- TiA uses the repository's Koerber item mapping; items 5, 7, 10, 15, and 16 are reversed as `6 - response`.
- Paired questionnaire comparisons report paired-t 95% confidence intervals, Cohen's dz, exact signed-rank p-values, and rank-biserial effect sizes. The small sample makes inference exploratory; results are unadjusted for multiple comparisons.
- Time is summarized per case. Paired comparisons average within participant and condition so every participant has equal weight.
- BI-RADS agreement is descriptive. Exact agreement requires the same numeric category. Bands are Low (1–2), Moderate (3–4), and High (5); BI-RADS 0 is shown both excluded and as a departure.
- Block position follows case row order; each participant's first three records are treated as the first block. Order splits are descriptive.
- Supplementary analyses use participant-level bootstrap intervals and Holm-adjusted questionnaire p-values; matched participant-case log-time ratios only where a pair appears in both conditions; and case-weighted versus participant-weighted assistant-agreement summaries with a first-presentation sensitivity. With eight participants, sparse matched cases, unequal case mix, and repeats in the second block, these are exploratory/descriptive. No stable case-adjusted or cluster-robust condition effect is claimed. The current pipeline regenerates some primary summary tables; review their diff before replacing committed results. In data-only mode, render and figure outputs are not updated.

The analysis does not treat agreement with the assistant as diagnostic accuracy against a clinical reference standard.
