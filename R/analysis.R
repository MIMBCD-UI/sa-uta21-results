# UTA21 data validation, scoring, statistics, tables, and figures.
# Called from scripts/run_analysis.R after it sets the project root as working directory.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
case_file <- file.path(root, "data", "mimbcdui_uta21_case_data.csv")
questionnaire_file <- file.path(root, "data", "mimbcdui_uta21_questionnaire_answers.csv")
out_dir <- file.path(root, "output")
table_dir <- file.path(out_dir, "tables")
figure_dir <- file.path(out_dir, "figures")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

required_packages <- c("ggplot2", "rmarkdown")
missing <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
data_only <- identical(Sys.getenv("UTA21_DATA_ONLY"), "true")
if (length(missing) && !data_only) {
  stop("Install required packages first: install.packages(c(",
       paste(sprintf("'%s'", missing), collapse = ", "), "))", call. = FALSE)
}
if (!data_only) suppressPackageStartupMessages(library(ggplot2))

write_table <- function(x, filename) write.csv(x, file.path(table_dir, filename), row.names = FALSE, na = "")
condition_cols <- c(C1 = "#2878B5", C2 = "#E07A3F")
group_cols <- c(expert = "#2878B5", novice = "#E07A3F")
theme_uta <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(plot.title = element_text(face = "bold", color = "#172B4D", size = rel(1.15)),
          plot.subtitle = element_text(color = "#526176"), axis.title = element_text(color = "#526176"),
          axis.text = element_text(color = "#26364A"), panel.grid.minor = element_blank(),
          panel.grid.major.y = element_line(color = "#E5EAF0", linewidth = .35),
          legend.position = "bottom", legend.title = element_blank(),
          strip.text = element_text(face = "bold", color = "#26364A"))
}
save_plot <- function(plot, filename, width, height) {
  ggsave(file.path(figure_dir, filename), plot, width = width, height = height,
         dpi = 320, bg = "white")
}

# Read case observations and validate identifiers, condition codes, response values, and durations.
cases <- read.csv(case_file, check.names = FALSE, stringsAsFactors = FALSE)
names(cases) <- trimws(names(cases))
case_cols <- c("participant_id", "expertise_level", "condition", "case_id", "time_on_task",
               "birads_assistant", "birads_radiologist", "action")
if (!all(case_cols %in% names(cases))) stop("Required case-data columns are missing.")
cases <- cases[!is.na(cases$condition) & !is.na(cases$participant_id) & nzchar(trimws(cases$participant_id)), ]
if (any(!cases$condition %in% c(1, 2))) stop("Condition codes must be 1 (C1) or 2 (C2).")
cases$condition <- factor(ifelse(cases$condition == 1, "C1", "C2"), levels = c("C1", "C2"))
cases$expertise_level <- factor(tolower(cases$expertise_level), levels = c("expert", "novice"))
parse_birads <- function(x) {
  result <- suppressWarnings(as.integer(sub("^(\\d+).*$", "\\1", trimws(as.character(x)))))
  if (anyNA(result)) stop("An unparseable BI-RADS response was found.")
  result
}
cases$birads_assistant <- parse_birads(cases$birads_assistant)
cases$birads_radiologist <- parse_birads(cases$birads_radiologist)
cases$time_seconds <- vapply(strsplit(trimws(cases$time_on_task), ":", fixed = TRUE),
  function(x) if (length(x) == 3) sum(as.numeric(x) * c(3600, 60, 1)) else NA_real_, numeric(1))
if (any(!is.finite(cases$time_seconds))) stop("A task duration could not be parsed as h:mm:ss.")
cases$block <- ave(seq_len(nrow(cases)), cases$participant_id,
  FUN = function(i) (seq_along(i) - 1) %/% 3 + 1)
cases$repeat_observation <- duplicated(paste(cases$participant_id, cases$case_id))
category_band <- function(x) ifelse(x %in% 1:2, "Low", ifelse(x %in% 3:4, "Moderate", ifelse(x == 5, "High", NA)))
cases$assistant_band <- category_band(cases$birads_assistant)
cases$participant_band <- category_band(cases$birads_radiologist)
cases$exact_agreement <- cases$birads_assistant == cases$birads_radiologist
cases$band_agreement <- !is.na(cases$participant_band) & cases$assistant_band == cases$participant_band
cases$participant_zero <- cases$birads_radiologist == 0
cases$action <- factor(trimws(cases$action), levels = c("accept", "edit->accept", "reject"))

# Questionnaire CSV row 1 contains scale labels; row 2 contains item names.
q <- read.csv(questionnaire_file, skip = 1, check.names = FALSE, stringsAsFactors = FALSE)
names(q) <- trimws(names(q))
q <- q[!is.na(q$condition), ]
if (any(!q$condition %in% c(1, 2))) stop("Questionnaire condition codes must be 1 (C1) or 2 (C2).")
q$condition <- factor(ifelse(q$condition == 1, "C1", "C2"), levels = c("C1", "C2"))
q[6:40] <- lapply(q[6:40], function(x) suppressWarnings(as.numeric(as.character(x))))
if (anyNA(q[6:40])) stop("Questionnaire item responses must be complete numeric values.")
sus <- as.matrix(q[6:15]); tlx <- as.matrix(q[16:21]); tia <- as.matrix(q[22:40])
if (ncol(sus) != 10 || ncol(tlx) != 6 || ncol(tia) != 19) stop("Unexpected questionnaire item counts.")
q$SUS <- (rowSums(sus[, c(1, 3, 5, 7, 9), drop = FALSE] - 1) +
          rowSums(5 - sus[, c(2, 4, 6, 8, 10), drop = FALSE])) * 2.5
tlX_performance_item <- 4
tlX_items <- tlx
tlX_items[, tlX_performance_item] <- 11 - tlX_items[, tlX_performance_item]
q$NASA_TLX <- rowMeans(tlX_items)
tia[, c(5, 7, 10, 15, 16)] <- 6 - tia[, c(5, 7, 10, 15, 16)]
tia_scales <- list(
  Reliability_Competence = c(1, 6, 10, 13, 15, 19),
  Understanding_Predictability = c(2, 7, 11, 16),
  Familiarity = c(3, 17), Intention_of_Developers = c(4, 8),
  Propensity_to_Trust = c(5, 12, 18), Trust_in_Automation = c(9, 14))
for (scale in names(tia_scales)) q[[scale]] <- rowMeans(tia[, tia_scales[[scale]], drop = FALSE])
measures <- c("SUS", "NASA_TLX", names(tia_scales))
labels <- c(SUS = "SUS", NASA_TLX = "NASA-TLX", Reliability_Competence = "Reliability / competence",
  Understanding_Predictability = "Understanding / predictability", Familiarity = "Familiarity",
  Intention_of_Developers = "Intention of developers", Propensity_to_Trust = "Propensity to trust",
  Trust_in_Automation = "Trust in automation")
if (anyDuplicated(q[c("participant_id", "condition")])) stop("Duplicate questionnaire participant-condition rows.")
condition_count <- table(q$participant_id, q$condition)
if (any(condition_count != 1)) stop("Each participant needs one questionnaire row per condition.")
wide <- reshape(q[c("participant_id", "expertise_level", "condition", measures)],
  idvar = c("participant_id", "expertise_level"), timevar = "condition", direction = "wide")

# Exact sign-permutation Wilcoxon signed-rank for the small paired sample.
rank_biserial <- function(d) {
  d <- round(d[d != 0], 10)
  if (!length(d)) return(NA_real_)
  r <- rank(abs(d)); (sum(r[d > 0]) - sum(r[d < 0])) / sum(r)
}
wilcoxon_exact <- function(d) {
  d <- round(d[d != 0], 10); n <- length(d)
  if (!n) return(c(W = 0, p = 1))
  r <- rank(abs(d)); w <- min(sum(r[d > 0]), sum(r[d < 0]))
  if (n > 20) return(c(W = w, p = suppressWarnings(wilcox.test(d, mu = 0, exact = FALSE)$p.value)))
  signs <- as.matrix(expand.grid(rep(list(c(0, 1)), n)))
  c(W = w, p = min(1, 2 * mean(as.vector(signs %*% r) <= w + 1e-9)))
}
paired_row <- function(variable) {
  c1 <- wide[[paste0(variable, ".C1")]]; c2 <- wide[[paste0(variable, ".C2")]]
  ok <- is.finite(c1) & is.finite(c2); d <- round(c2[ok] - c1[ok], 10)
  ci <- t.test(c2[ok], c1[ok], paired = TRUE)$conf.int
  w <- wilcoxon_exact(d)
  data.frame(measure = labels[[variable]], n = length(d), C1_mean = mean(c1[ok]), C1_sd = sd(c1[ok]),
    C2_mean = mean(c2[ok]), C2_sd = sd(c2[ok]), mean_difference_C2_minus_C1 = mean(d),
    CI95_low = ci[1], CI95_high = ci[2], cohens_dz = mean(d) / sd(d),
    wilcoxon_W = unname(w["W"]), wilcoxon_r_rank_biserial = rank_biserial(d),
    wilcoxon_p = unname(w["p"]), decreased = sum(d < 0), increased = sum(d > 0), unchanged = sum(d == 0))
}
questionnaire_summary <- do.call(rbind, lapply(measures, paired_row))
write_table(questionnaire_summary, "questionnaire_paired_comparisons.csv")
score_long <- do.call(rbind, lapply(measures, function(v) data.frame(participant_id = q$participant_id,
  expertise_level = q$expertise_level, condition = q$condition, measure = labels[[v]], score = q[[v]])))
write_table(score_long, "questionnaire_scores_by_participant.csv")
group_parts <- split(score_long, interaction(score_long$measure, score_long$expertise_level,
  score_long$condition, drop = TRUE))
group_summary <- do.call(rbind, lapply(group_parts, function(d) data.frame(measure = d$measure[1],
  expertise_level = d$expertise_level[1], condition = d$condition[1], n = nrow(d),
  mean = mean(d$score), sd = sd(d$score))))
write_table(group_summary, "questionnaire_by_experience.csv")

# Descriptive case-time summaries, participant-weighted paired comparison, and order summaries.
time_parts <- split(cases, interaction(cases$condition, cases$expertise_level, drop = TRUE))
time_summary <- do.call(rbind, lapply(time_parts, function(d) data.frame(condition = d$condition[1],
  expertise_level = d$expertise_level[1], n = nrow(d), mean_seconds = mean(d$time_seconds),
  median_seconds = median(d$time_seconds), sd_seconds = sd(d$time_seconds))))
write_table(time_summary, "time_on_task_summary.csv")
time_by_person <- aggregate(cases$time_seconds, list(participant_id = cases$participant_id, condition = cases$condition), mean)
names(time_by_person)[3] <- "time_seconds"
time_wide <- reshape(time_by_person, idvar = "participant_id", timevar = "condition", direction = "wide")
time_d <- round(time_wide$time_seconds.C2 - time_wide$time_seconds.C1, 10)
time_ci <- t.test(time_wide$time_seconds.C2, time_wide$time_seconds.C1, paired = TRUE)$conf.int
time_w <- wilcoxon_exact(time_d)
write_table(data.frame(measure = "Participant mean time (seconds)", n = length(time_d),
  C1_mean = mean(time_wide$time_seconds.C1), C1_sd = sd(time_wide$time_seconds.C1),
  C2_mean = mean(time_wide$time_seconds.C2), C2_sd = sd(time_wide$time_seconds.C2),
  mean_difference_C2_minus_C1 = mean(time_d), CI95_low = time_ci[1], CI95_high = time_ci[2],
  cohens_dz = mean(time_d) / sd(time_d), wilcoxon_W = unname(time_w["W"]),
  wilcoxon_r_rank_biserial = rank_biserial(time_d), wilcoxon_p = unname(time_w["p"]),
  decreased = sum(time_d < 0), increased = sum(time_d > 0), unchanged = sum(time_d == 0)),
  "time_on_task_paired_comparison.csv")

agreement_parts <- list()
for (v in c("exact_agreement", "band_agreement")) {
  for (key in split(cases, interaction(cases$condition, cases$expertise_level, drop = TRUE))) {
    d <- key
    use <- if (v == "band_agreement") !d$participant_zero else rep(TRUE, nrow(d))
    value <- d[[v]][use]
    agreement_parts[[length(agreement_parts) + 1]] <- data.frame(condition = d$condition[1],
      expertise_level = d$expertise_level[1], measure = if (v == "exact_agreement") "Exact agreement" else "Suspicion-band agreement",
      n = length(value), agreements = sum(value), proportion = mean(value))
    if (v == "band_agreement") agreement_parts[[length(agreement_parts) + 1]] <- data.frame(
      condition = d$condition[1], expertise_level = d$expertise_level[1],
      measure = "Suspicion-band agreement (BI-RADS 0 as departure)", n = nrow(d),
      agreements = sum(d[[v]], na.rm = TRUE), proportion = mean(d[[v]], na.rm = TRUE))
  }
}
write_table(do.call(rbind, agreement_parts), "birads_agreement_summary.csv")
order_info <- do.call(rbind, lapply(split(cases, cases$participant_id), function(d) data.frame(
  participant_id = d$participant_id[1], expertise_level = d$expertise_level[1],
  first_condition = as.character(d$condition[1]),
  first_block_mean_seconds = mean(d$time_seconds[d$block == 1]),
  second_block_mean_seconds = mean(d$time_seconds[d$block == 2]))))
order_info$time_change_second_minus_first <- order_info$second_block_mean_seconds - order_info$first_block_mean_seconds
write_table(order_info, "condition_order_by_participant.csv")
order_scores <- do.call(rbind, lapply(measures, function(v) data.frame(participant_id = wide$participant_id,
  first_condition = order_info$first_condition[match(wide$participant_id, order_info$participant_id)],
  measure = labels[[v]], difference = wide[[paste0(v, ".C2")]] - wide[[paste0(v, ".C1")]])))
order_parts <- split(order_scores, interaction(order_scores$measure, order_scores$first_condition, drop = TRUE))
order_summary <- do.call(rbind, lapply(order_parts, function(d) data.frame(measure = d$measure[1],
  first_condition = d$first_condition[1], n = nrow(d), mean_difference = mean(d$difference), sd = sd(d$difference))))
write_table(order_summary, "condition_order_questionnaire_differences.csv")
action_summary <- as.data.frame.matrix(table(cases$condition, cases$action))
action_summary$condition <- rownames(action_summary)
write_table(action_summary, "suggestion_actions.csv")

if (data_only) {
  cat("Data-only analysis complete. Tables written to", table_dir, "\n")
} else {
  # Stable palettes, readable labels, and participant-level points for appendix figures.
  p_scores <- ggplot(score_long, aes(condition, score, group = participant_id, color = expertise_level)) +
    geom_line(alpha = .35, linewidth = .45) + geom_point(size = 2.1, position = position_jitter(width = .035)) +
    stat_summary(aes(group = condition), fun = mean, geom = "crossbar", width = .52, color = "#172B4D", linewidth = .55) +
    facet_wrap(~measure, scales = "free_y", ncol = 2) + scale_color_manual(values = group_cols) +
    labs(title = "Questionnaire scores by condition", subtitle = "Lines connect participants; bars show condition means.",
      x = NULL, y = "Score", color = "Experience") + theme_uta()
  save_plot(p_scores, "questionnaire_scores.png", 9, 7)
  forest <- questionnaire_summary; forest$measure <- factor(forest$measure, levels = rev(forest$measure))
  p_forest <- ggplot(forest, aes(mean_difference_C2_minus_C1, measure)) +
    geom_vline(xintercept = 0, color = "#8A97A8", linetype = 2) +
    geom_errorbar(aes(xmin = CI95_low, xmax = CI95_high), width = .18, color = "#2878B5", linewidth = .7) +
    geom_point(size = 2.7, color = "#2878B5") +
    labs(title = "Paired questionnaire differences", subtitle = "C2 minus C1; bars show 95% paired-t confidence intervals.",
      x = "Mean paired difference", y = NULL) + theme_uta()
  save_plot(p_forest, "questionnaire_paired_differences.png", 9, 5.5)
  cases$block_label <- factor(cases$block, levels = c(1, 2), labels = c("First block", "Second block"))
  p_time <- ggplot(cases, aes(condition, time_seconds, fill = condition)) +
    geom_boxplot(width = .5, alpha = .45, outlier.shape = NA, color = "#26364A") +
    geom_point(aes(color = condition), position = position_jitter(width = .08), alpha = .72, size = 2) +
    facet_wrap(~expertise_level, labeller = as_labeller(c(expert = "Experts", novice = "Novices"))) +
    scale_fill_manual(values = condition_cols) + scale_color_manual(values = condition_cols) +
    labs(title = "Time on task by condition and experience", subtitle = "Each point is one case observation.",
      x = NULL, y = "Time on task (seconds)") + theme_uta() + theme(legend.position = "none")
  save_plot(p_time, "time_on_task.png", 8.2, 4.8)
  p_block <- ggplot(cases, aes(block_label, time_seconds, fill = condition)) +
    geom_boxplot(position = position_dodge(width = .72), width = .6, alpha = .6, outlier.shape = NA) +
    geom_point(aes(color = condition), position = position_jitterdodge(jitter.width = .08, dodge.width = .72), alpha = .6, size = 1.7) +
    scale_fill_manual(values = condition_cols) + scale_color_manual(values = condition_cols) +
    labs(title = "Time on task by block and condition", subtitle = "Block follows source row order within participant.",
      x = NULL, y = "Time on task (seconds)") + theme_uta()
  save_plot(p_block, "time_by_block.png", 8.2, 4.8)
  agreement_long <- rbind(data.frame(condition = cases$condition, expertise_level = cases$expertise_level,
    measure = "Exact BI-RADS", agreed = as.integer(cases$exact_agreement), participant_zero = cases$participant_zero),
    data.frame(condition = cases$condition, expertise_level = cases$expertise_level,
      measure = "Suspicion band", agreed = as.integer(cases$band_agreement), participant_zero = cases$participant_zero))
  agreement_long <- agreement_long[!(agreement_long$measure == "Suspicion band" & agreement_long$participant_zero), ]
  p_agreement <- ggplot(agreement_long, aes(condition, agreed, color = expertise_level)) +
    geom_jitter(width = .1, height = .035, alpha = .42, size = 1.6) +
    stat_summary(aes(group = interaction(condition, expertise_level)), fun = mean, geom = "point",
      shape = 18, size = 4, position = position_dodge(width = .34)) + facet_wrap(~measure) +
    scale_color_manual(values = group_cols) + scale_y_continuous(breaks = c(0, 1), labels = c("No", "Yes"), limits = c(-.1, 1.1)) +
    labs(title = "Assistant-participant agreement", subtitle = "Band agreement omits participant BI-RADS 0.",
      x = NULL, y = "Agreement", color = "Experience") + theme_uta()
  save_plot(p_agreement, "birads_agreement.png", 8.2, 4.8)
}
