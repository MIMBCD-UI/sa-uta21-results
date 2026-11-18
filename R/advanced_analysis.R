# Supplementary, design-aware analyses for the small UTA21 evaluation.
# Sourced by R/analysis.R after source files and scoring conventions are loaded.

set.seed(21021)
advanced_methods <- c(
  "Paired questionnaire differences: percentile participant bootstrap intervals and Holm-adjusted exact signed-rank p-values.",
  "Task time: paired log-time contrasts restricted to participant-case pairs observed in both conditions; participant summaries and first-presentation sensitivity are reported separately.",
  "Assistant-participant agreement: raw case summaries plus participant-weighted summaries and a first-presentation sensitivity; no cluster-based inferential interval is claimed."
)

# Percentile bootstrap resamples the eight participant-level paired differences.
# It is descriptive with this small sample and does not solve generalizability.
bootstrap_mean_ci <- function(x, B = 20000L) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 2L) return(c(low = NA_real_, high = NA_real_))
  draws <- replicate(B, mean(sample(x, size = n, replace = TRUE)))
  stats::quantile(draws, c(.025, .975), names = FALSE, type = 6)
}

advanced_questionnaire <- do.call(rbind, lapply(measures, function(variable) {
  c1 <- wide[[paste0(variable, ".C1")]]
  c2 <- wide[[paste0(variable, ".C2")]]
  d <- c2 - c1
  ci <- bootstrap_mean_ci(d)
  base <- questionnaire_summary[questionnaire_summary$measure == labels[[variable]], ]
  data.frame(measure = labels[[variable]], n_participants = sum(is.finite(d)),
    mean_difference_C2_minus_C1 = mean(d), bootstrap95_low = ci[1], bootstrap95_high = ci[2],
    exact_signed_rank_p = base$wilcoxon_p, stringsAsFactors = FALSE)
}))
advanced_questionnaire$holm_p <- p.adjust(advanced_questionnaire$exact_signed_rank_p, method = "holm")
write_table(advanced_questionnaire, "advanced_questionnaire_sensitivity.csv")

# Overlap diagnostics and paired participant-case log-time comparisons.
pair_key <- paste(cases$participant_id, cases$case_id, sep = "::")
case_pair_counts <- aggregate(cases$condition, list(pair = pair_key), function(x) length(unique(x)))
paired_keys <- case_pair_counts$pair[case_pair_counts$x == 2L]
paired_time <- cases[pair_key %in% paired_keys, c("participant_id", "case_id", "condition", "time_seconds", "block")]
if (nrow(paired_time)) {
  pw <- reshape(paired_time[c("participant_id", "case_id", "condition", "time_seconds")],
    idvar = c("participant_id", "case_id"), timevar = "condition", direction = "wide")
  pw$log_ratio_C2_to_C1 <- log(pw$time_seconds.C2 / pw$time_seconds.C1)
  pw$ratio_C2_to_C1 <- exp(pw$log_ratio_C2_to_C1)
  write_table(pw, "advanced_matched_case_time.csv")
  person_parts <- split(pw, pw$participant_id)
  person_time <- do.call(rbind, lapply(person_parts, function(d) data.frame(
    participant_id = d$participant_id[1], n_matched_cases = nrow(d),
    mean_log_ratio_C2_to_C1 = mean(d$log_ratio_C2_to_C1),
    geometric_mean_ratio_C2_to_C1 = exp(mean(d$log_ratio_C2_to_C1)),
    stringsAsFactors = FALSE)))
  write_table(person_time, "advanced_matched_case_time_by_participant.csv")
} else {
  pw <- data.frame()
  person_time <- data.frame()
  write_table(pw, "advanced_matched_case_time.csv")
  write_table(person_time, "advanced_matched_case_time_by_participant.csv")
}

case_mix <- aggregate(cases$time_seconds, list(condition = cases$condition, case_id = cases$case_id),
  function(x) c(n = length(x), median_seconds = median(x), mean_seconds = mean(x)))
case_mix_out <- data.frame(condition = case_mix$condition, case_id = case_mix$case_id,
  n = case_mix$x[, "n"], median_seconds = case_mix$x[, "median_seconds"], mean_seconds = case_mix$x[, "mean_seconds"])
write_table(case_mix_out, "advanced_case_time_coverage.csv")

first <- cases[!cases$repeat_observation, ]
first_time <- aggregate(first$time_seconds, list(condition = first$condition), function(x)
  c(n = length(x), median_seconds = median(x), mean_seconds = mean(x)))
first_time_out <- data.frame(condition = first_time$condition, n = first_time$x[, "n"],
  median_seconds = first_time$x[, "median_seconds"], mean_seconds = first_time$x[, "mean_seconds"])
write_table(first_time_out, "advanced_first_presentation_time.csv")

time_diagnostics <- data.frame(
  quantity = c("Case observations", "Participant-case pairs observed in both conditions",
    "Participants with at least one matched case", "Repeated presentations excluded in first-presentation sensitivity"),
  value = c(nrow(cases), length(paired_keys), length(unique(pw$participant_id)), sum(cases$repeat_observation)),
  stringsAsFactors = FALSE)
write_table(time_diagnostics, "advanced_time_design_diagnostics.csv")

# Agreement outcomes are not diagnostic accuracy. Quantify both case-weighted
# and participant-weighted rates; participant means avoid giving more weight to
# participants with more observed records within a condition.
agreement_long <- do.call(rbind, lapply(c("exact_agreement", "band_agreement"), function(v) {
  d <- cases
  if (v == "band_agreement") d <- d[!d$participant_zero, ]
  d$agreement <- as.integer(d[[v]])
  d$measure <- if (v == "exact_agreement") "Exact agreement" else "Suspicion-band agreement (BI-RADS 0 excluded)"
  d
}))
agreement_summary <- do.call(rbind, lapply(split(agreement_long,
  interaction(agreement_long$measure, agreement_long$condition, drop = TRUE)), function(d) {
    per_person <- aggregate(d$agreement, list(participant_id = d$participant_id), mean)
    data.frame(measure = d$measure[1], condition = d$condition[1], n_case_observations = nrow(d),
      case_weighted_rate = mean(d$agreement), n_participants = nrow(per_person),
      participant_weighted_rate = mean(per_person$x), stringsAsFactors = FALSE)
  }))
write_table(agreement_summary, "advanced_agreement_weighting.csv")

first_agreement <- do.call(rbind, lapply(c("exact_agreement", "band_agreement"), function(v) {
  d <- first
  if (v == "band_agreement") d <- d[!d$participant_zero, ]
  d$agreement <- as.integer(d[[v]])
  d$measure <- if (v == "exact_agreement") "Exact agreement" else "Suspicion-band agreement (BI-RADS 0 excluded)"
  d
}))
first_summary <- do.call(rbind, lapply(split(first_agreement,
  interaction(first_agreement$measure, first_agreement$condition, drop = TRUE)), function(d) {
    pp <- aggregate(d$agreement, list(participant_id = d$participant_id), mean)
    data.frame(measure = d$measure[1], condition = d$condition[1], n_first_presentations = nrow(d),
      agreements = sum(d$agreement), case_weighted_rate = mean(d$agreement), n_participants = nrow(pp),
      participant_weighted_rate = mean(pp$x), stringsAsFactors = FALSE)
  }))
write_table(first_summary, "advanced_first_presentation_agreement.csv")

advanced_decisions <- data.frame(
  analysis = c("Questionnaires", "Task time", "Assistant-participant agreement"),
  estimand = c("Mean within-participant C2 minus C1 difference for each scored scale.",
    "C2:C1 time ratio among participant-case pairs appearing in both conditions; separately, observed case mix and first presentations.",
    "Observed exact or band agreement rates, shown case-weighted and participant-weighted, with a first-presentation sensitivity."),
  assumptions = c("Participants are the resampling units; paired differences are exchangeable for the percentile bootstrap.",
    "Matched cases are comparable across conditions; log ratios are meaningful. This overlap estimand applies only to matched pairs.",
    "Recorded assistant and participant categories and the documented bands are accurate; rates describe this sample only."),
  diagnostics = c("Paired n, bootstrap interval, original exact signed-rank p, and Holm-adjusted p.",
    "Matched-pair count and participant coverage, per-pair and per-participant ratios, case-specific coverage, first-presentation summaries.",
    "Raw numerators/denominators, number of participants, weighting comparison, and first-presentation sensitivity."),
  limitations = c("Only eight participants; bootstrap intervals may have poor coverage. Holm adjustment is conservative and exploratory.",
    "Sparse overlap, order/block confounding, unequal case allocation, and repeated exposures limit generalization and causal interpretation.",
    "No clinical reference standard; participant clusters and cases are too few for dependable cluster-robust inference or complex mixed models."),
  stringsAsFactors = FALSE)
write_table(advanced_decisions, "advanced_methods_register.csv")
