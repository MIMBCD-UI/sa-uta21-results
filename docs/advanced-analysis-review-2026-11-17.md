# Supplementary UTA21 analysis review

**Review date:** 17 November 2026  
**Repository:** `sa-uta21-results`  
**Status:** Review of current source and output files; no analysis code or source data changed by this review.

## Evidence checked

- `data/mimbcdui_uta21_case_data.csv`
- `data/mimbcdui_uta21_questionnaire_answers.csv`
- `data/mimbcdui_uta21_case_provenance.csv`
- `README.md`, `R/analysis.R`, `R/advanced_analysis.R`, `src/uta21_analysis.R`
- Existing primary and supplementary CSVs under `output/tables/`
- Supplementary report sections in `report/uta21_analysis_report.Rmd`

## Verified design and conventions

The included records contain 8 participants, 48 case observations, 10 repeated participant-case presentations, and 24 case observations per condition. Each participant contributes three observations per condition. The assistant-category and case allocations differ by condition. Row order gives five C1-first and three C2-first participants; no separate timestamp or explicit sequence field was found. `scenario_id` groups the six observations for each participant, with three rows in one condition followed by three in the other.

C1 is Clinical-First; C2 is Regulatory-First; questionnaire differences are C2 minus C1. Questionnaire scoring in the analysis source matches the documented conventions: standard SUS; an unweighted six-item adapted NASA-TLX composite with item 4 reversed; and the documented TiA subscales with items 5, 7, 10, 15, and 16 reversed. Assistant-participant agreement is not diagnostic accuracy against an independent reference standard.

## Supplementary methods review

| Analysis | Question and estimand | Assumptions and diagnostics present | Limitations and review finding |
|---|---|---|---|
| Questionnaire bootstrap and multiplicity | For each scale, the mean within-participant C2−C1 score difference. Percentile intervals resample the eight participant differences; Holm adjustment covers the eight signed-rank p-values. | The code uses participants as resampling units, sets a seed, generates 20,000 bootstrap draws, and reports paired n, intervals, exact signed-rank p-values, and adjusted p-values. The primary per-participant score table and figure support inspection of individual results. | Eight participants give unstable percentile intervals and limited generalizability. The exact sign-permutation signed-rank test depends on exchangeable signs/symmetry under its null. **Output discrepancy:** current `R/analysis.R` writes `wilcoxon_W` using the exact sign-permutation function; `output/tables/questionnaire_paired_comparisons.csv` has legacy `wilcoxon_V` and a Reliability/competence p-value of about 0.022254, while the supplementary table reports 0.015625. The supplementary code copies the in-memory primary p-value, so the checked-in tables do not represent one synchronized run. Reconcile by controlled rerun and output diff before interpretation. |
| Matched participant-case time ratios | For each participant-case observed in both conditions, the C2:C1 time ratio, computed as `time_seconds.C2 / time_seconds.C1`; per participant, the geometric mean of available matched ratios. | Matching uses participant and case IDs. The output provides 10 pair ratios, participant summaries for all 8 participants, condition-by-case coverage, and first-presentation summaries. | The estimand is restricted to the 10 observed overlap pairs, not an overall condition effect. Those pairs are repeated presentations in a later block; condition and period/carryover cannot be separated in these data. No pooled inferential interval or adjusted model is produced. Treat as descriptive sensitivity only. |
| Weighted agreement and first-presentation sensitivity | Observed exact- and suspicion-band agreement rates by condition, case-weighted and as an equal-weight average of participant-specific rates; repeated records are also excluded in a first-presentation sensitivity. | The outputs provide condition-specific denominators, weighting comparisons, participant counts, and first-presentation counts. Band agreement excludes participant BI-RADS 0. | This is descriptive concordance, not accuracy. Denominators are 24/24 for exact agreement, 24 for C1 band agreement and 21 for C2 band agreement. First-presentation totals are 21 for C1 and 17 for C2; band denominators are 21 and 14. **Output omission:** `advanced_agreement_weighting.csv` gives denominators and rates but omits the numerator counts, despite the methods register saying raw numerators/denominators are reported. The primary agreement table or explicit counts should be consulted if this table is reused independently. No cluster-robust or causal condition effect is supported. |

## Additional limits and outputs

- The supplementary methods are exploratory/descriptive. No Bayesian paired model, order-adjusted questionnaire model, or case/period-adjusted time model is implemented in `R/advanced_analysis.R`.
- `category_level` is participant seniority, not case complexity. Assistant BI-RADS is an output of the interaction and should not be treated casually as a baseline case-mix adjustment variable. Case identity and provenance modality counts are available for description, but modality count is constant within case.
- The README warns that running the current pipeline rewrites primary outputs. Compare generated tables with the restored primary files before accepting changes.
- Cross-thread handoff reports that the data-only run passed and that HTML/figure rendering was not completed because `ggplot2` and `rmarkdown` were unavailable. That run status was not independently rerun during this review.
- No source CSV was changed. No analysis rerun or report render was performed for this review.

## Coordination handoff

This review is intended for **“UTA21 Analysis and Cross-Chat Mapping”** (Codex thread `01a1ebc7-b0f6-71a0-9af5-f043b7536ad6`) and **“UTA21 Statistical Analysis Planning and Coordination”** (ChatGPT thread `6afcd756-bc9c-83ed-87f9-d4f6147a3503`). The repository thread map records those IDs. I attempted to send the review to both threads, but the app's `send_message_to_thread` calls failed. The document remains the durable handoff for those discussions.

Recommended decisions for coordination: retain the supplementary methods as exploratory; reconcile questionnaire p-value outputs against a single controlled run; add numerator counts to the weighted-agreement output if it is intended to stand alone; do not interpret matched ratios as an adjusted or causal overall condition effect; and do not add complex agreement models without substantially stronger data.
