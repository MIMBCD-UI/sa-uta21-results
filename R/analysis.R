# Data preparation, scoring, statistics, tables, and plots for UTA21.
# Run via scripts/run_analysis.R from the project root.

options(stringsAsFactors = FALSE)

# The runner sets the working directory to the project root before sourcing.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
case_path <- file.path(root, "data", "mimbcdui_uta21_case_data.csv")
questionnaire_path <- file.path(root, "data", "mimbcdui_uta21_questionnaire_answers.csv")
out_dir <- file.path(root, "output")
table_dir <- file.path(out_dir, "tables")
figure_dir <- file.path(out_dir, "figures")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

required_packages <- c("ggplot2", "rmarkdown", "knitr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) && !identical(Sys.getenv("UTA21_DATA_ONLY"), "true")) {
  stop("Install required packages first: install.packages(c(",
       paste(sprintf('"%s"', missing_packages), collapse = ", "), "))", call. = FALSE)
}
if (!identical(Sys.getenv("UTA21_DATA_ONLY"), "true")) suppressPackageStartupMessages(library(ggplot2))

theme_uta <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(plot.title = element_text(face = "bold", color = "#172B4D", size = rel(1.15)),
          plot.subtitle = element_text(color = "#526176"),
          axis.title = element_text(color = "#526176"),
          axis.text = element_text(color = "#26364A"),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_line(color = "#E5EAF0", linewidth = .35),
          legend.position = "bottom", legend.title = element_blank(),
          strip.text = element_text(face = "bold", color = "#26364A"),
          plot.caption = element_text(color = "#68778A", size = rel(.8)))
}
condition_cols <- c(C1 = "#2878B5", C2 = "#E07A3F")
group_cols <- c(expert = "#2878B5", novice = "#E07A3F")

write_table <- function(x, name) {
  write.csv(x, file.path(table_dir, name), row.names = FALSE, na = "")
}
save_plot <- function(p, name, width = 8.2, height = 5.2) {
  ggsave(file.path(figure_dir, name), p, width = width, height = height,
         dpi = 320, bg = "white")
}

# Read and validate the case-level observations.
cases <- read.csv(case_path, check.names = FALSE, stringsAsFactors = FALSE)
names(cases) <- trimws(names(cases))
case_required <- c("participant_id", "expertise_level", "condition", "case_id",
                   "time_on_task", "birads_assistant", "birads_radiologist", "action")
if (!all(case_required %in% names(cases))) stop("Required case-data columns are missing.")
cases <- cases[!is.na(cases$condition) & nzchar(trimws(cases$participant_id)), ]
if (any(!cases$condition %in% c(1, 2))) stop("Condition values must be 1 (C1) or 2 (C2).")
cases$condition <- factor(ifelse(cases$condition == 1, "C1", "C2"), levels = c("C1", "C2"))
cases$expertise_level <- factor(tolower(cases$expertise_level), levels = c("expert", "novice"))
parse_category <- function(x) {
  value <- suppressWarnings(as.integer(sub("^(\\d+).*$", "\\1", trimws(as.character(x)))))
  if (anyNA(value)) stop("Unparseable BI-RADS response found.")
  value
}
cases$birads_assistant <- parse_category(cases$birads_assistant)
cases$birads_radiologist <- parse_category(cases$birads_radiologist)
cases$time_seconds <- vapply(strsplit(trimws(cases$time_on_task), ":", fixed = TRUE),
                             function(x) sum(as.numeric(x) * c(3600, 60, 1)), numeric(1))
if (any(!is.finite(cases$time_seconds))) stop("Unparseable task duration found.")
cases$block <- ave(seq_len(nrow(cases)), cases$participant_id, FUN = function(i) (seq_along(i) - 1) %/% 3 + 1)
cases$repeat_observation <- duplicated(paste(cases$participant_id, cases$case_id))
category_band <- function(x) ifelse(x %in% 1:2, "Low", ifelse(x %in% 3:4, "Moderate", ifelse(x == 5, "High", NA)))
cases$assistant_band <- category_band(cases$birads_assistant)
cases$participant_band <- category_band(cases$birads_radiologist)
cases$exact_agreement <- cases$birads_assistant == cases$birads_radiologist
cases$band_agreement <- !is.na(cases$participant_band) & cases$assistant_band == cases$participant_band
cases$participant_zero <- cases$birads_radiologist == 0
cases$action <- factor(trimws(cases$action), levels = c("accept", "edit->accept", "reject"))

# Questionnaire file has a descriptive first header row and item names in row 2.
q <- read.csv(questionnaire_path, skip = 1, check.names = FALSE, stringsAsFactors = FALSE)
names(q) <- trimws(names(q))
q <- q[!is.na(q$condition), ]
if (any(!q$condition %in% c(1, 2))) stop("Questionnaire condition values must be 1 (C1) or 2 (C2).")
q$condition <- factor(ifelse(q$condition == 1, "C1", "C2"), levels = c("C1", "C2"))
score_cols <- 6:40
q[score_cols] <- lapply(q[score_cols], function(x) suppressWarnings(as.numeric(as.character(x))))
if (anyNA(q[score_cols])) stop("Missing or non-numeric questionnaire item responses found.")
sus_items <- as.matrix(q[6:15])
tlx_items <- as.matrix(q[16:21])
tia_items <- as.matrix(q[22:40])
if (ncol(sus_items) != 10 || ncol(tlx_items) != 6 || ncol(tia_items) != 19) stop("Unexpected questionnaire item counts.")

q$SUS <- (rowSums(sus_items[, c(1, 3, 5, 7, 9), drop = FALSE] - 1) +
            rowSums(5 - sus_items[, c(2, 4, 6, 8, 10), drop = FALSE])) * 2.5
tlx_items[, 4] <- 11 - tlx_items[, 4]
q$NASA_TLX <- rowMeans(tlx_items)
tia_items[, c(5, 7, 10, 15, 16)] <- 6 - tia_items[, c(5, 7, 10, 15, 16)]
tia_scales <- list(
  Reliability_Competence = c(1, 6, 10, 13, 15, 19),
  Understanding_Predictability = c(2, 7, 11, 16),
  Familiarity = c(3, 17),
  Intention_of_Developers = c(4, 8),
  Propensity_to_Trust = c(5, 12, 18),
  Trust_in_Automation = c(9, 14)
)
for (scale in names(tia_scales)) q[[scale]] <- rowMeans(tia_items[, tia_scales[[scale]], drop = FALSE])
measures <- c("SUS", "NASA_TLX", names(tia_scales))
measure_labels <- c(SUS = "SUS", NASA_TLX = "NASA-TLX", Reliability_Competence = "Reliability / competence",
                    Understanding_Predictability = "Understanding / predictability", Familiarity = "Familiarity",
                    Intention_of_Developers = "Intention of developers", Propensity_to_Trust = "Propensity to trust",
                    Trust_in_Automation = "Trust in automation")

# Ensure every paired comparison is based on one C1 and one C2 score per person.
if (anyDuplicated(q[c("participant_id", "condition")])) stop("Duplicate questionnaire participant-condition rows.")
condition_counts <- table(q$participant_id, q$condition)
if (any(condition_counts != 1)) stop("Each questionnaire participant must have exactly one row in C1 and C2.")
wide <- reshape(q[c("participant_id", "expertise_level", "condition", measures)],
                idvar = c("participant_id", "expertise_level"), timevar = "condition", direction = "wide")
rank_biserial <- function(d) {
  d <- round(d[d != 0], 10)
  if (!length(d)) return(NA_real_)
  ranks <- rank(abs(d))
  (sum(ranks[d > 0]) - sum(ranks[d < 0])) / sum(ranks)
}
wilcoxon_exact <- function(d) {
  d <- round(d[d != 0], 10)
  n <- length(d)
  if (!n) return(c(W = 0, p = 1))
  ranks <- rank(abs(d))
  w <- min(sum(ranks[d > 0]), sum(ranks[d < 0]))
  if (n > 20) {
    p <- suppressWarnings(wilcox.test(d, mu = 0, exact = FALSE)$p.value)
  } else {
    signs <- as.matrix(expand.grid(rep(list(c(0, 1)), n)))
    all_w <- as.vector(signs %*% ranks)
    p <- min(1, 2 * mean(all_w <= w + 1e-9))
  }
  c(W = w, p = p)
}
paired <- function(variable, label = measure_labels[[variable]]) {
  c1 <- wide[[paste0(variable, ".C1")]]
  c2 <- wide[[paste0(variable, ".C2")]]
  ok <- is.finite(c1) & is.finite(c2)
  d <- round(c2[ok] - c1[ok], 10)
  n <- length(d)
  ci <- if (n > 1) t.test(c2[ok], c1[ok], paired = TRUE)$conf.int else c(NA_real_, NA_real_)
  dz <- if (n > 1 && sd(d) > 0) mean(d) / sd(d) else NA_real_
  w <- wilcoxon_exact(d)
  data.frame(measure = label, n = n, C1_mean = mean(c1[ok]), C1_sd = sd(c1[ok]),
             C2_mean = mean(c2[ok]), C2_sd = sd(c2[ok]), mean_difference_C2_minus_C1 = mean(d),
             CI95_low = ci[1], CI95_high = ci[2], cohens_dz = dz,
             wilcoxon_W = unname(w["W"]), wilcoxon_r_rank_biserial = rank_biserial(d),
             wilcoxon_p = unname(w["p"]), decreased = sum(d < 0), increased = sum(d > 0), unchanged = sum(d == 0))
}
questionnaire_summary <- do.call(rbind, lapply(measures, paired))

score_long <- do.call(rbind, lapply(measures, function(v) data.frame(
  participant_id = q$participant_id, expertise_level = q$expertise_level,
  condition = q$condition, measure = measure_labels[[v]], score = q[[v]])))
score_long$expertise_level <- factor(score_long$expertise_level, levels = c("expert", "novice"))
write_table(questionnaire_summary, "questionnaire_paired_comparisons.csv")
write_table(score_long, "questionnaire_scores_by_participant.csv")

group_split <- split(score_long, interaction(score_long$measure, score_long$expertise_level,
                                             score_long$condition, drop = TRUE))
group_summary <- do.call(rbind, lapply(group_split, function(d) data.frame(
  measure = d$measure[1], expertise_level = d$expertise_level[1], condition = d$condition[1],
  n = nrow(d), mean = mean(d$score), sd = sd(d$score))))
write_table(group_summary, "questionnaire_by_experience.csv")

# Case-level descriptive summaries, agreement, and condition order.
time_split <- split(cases, interaction(cases$condition, cases$expertise_level, drop = TRUE))
time_summary <- do.call(rbind, lapply(time_split, function(d) data.frame(
  condition = d$condition[1], expertise_level = d$expertise_level[1], n = nrow(d),
  mean_seconds = mean(d$time_seconds), median_seconds = median(d$time_seconds),
  sd_seconds = sd(d$time_seconds))))
write_table(time_summary, "time_on_task_summary.csv")

# Keep a tidy agreement table with explicit measures.
agreement_rows <- do.call(rbind, lapply(c("exact_agreement", "band_agreement"), function(v) {
  groups <- split(cases, interaction(cases$condition, cases$expertise_level, drop = TRUE))
  do.call(rbind, lapply(groups, function(d) {
    usable <- if (v == "band_agreement") !d$participant_zero else rep(TRUE, nrow(d))
    vals <- d[[v]][usable]
    rows <- data.frame(condition = d$condition[1], expertise_level = d$expertise_level[1],
               measure = if (v == "exact_agreement") "Exact agreement" else "Suspicion-band agreement",
               n = length(vals), agreements = sum(vals), proportion = mean(vals))
    if (v == "band_agreement") rows <- rbind(rows, data.frame(
      condition = d$condition[1], expertise_level = d$expertise_level[1],
      measure = "Suspicion-band agreement (BI-RADS 0 as departure)",
      n = nrow(d), agreements = sum(d[[v]], na.rm = TRUE), proportion = mean(d[[v]], na.rm = TRUE)))
    rows
  }))
}))
write_table(agreement_rows, "birads_agreement_summary.csv")

order_info <- do.call(rbind, lapply(split(cases, cases$participant_id), function(d) {
  d <- d[order(seq_len(nrow(d))), ]
  data.frame(participant_id = d$participant_id[1], expertise_level = d$expertise_level[1],
             first_condition = as.character(d$condition[1]),
             first_block_mean_seconds = mean(d$time_seconds[d$block == 1]),
             second_block_mean_seconds = mean(d$time_seconds[d$block == 2]))
}))
order_info$time_change_second_minus_first <- order_info$second_block_mean_seconds - order_info$first_block_mean_seconds
write_table(order_info, "condition_order_by_participant.csv")
order_scores <- do.call(rbind, lapply(measures, function(v) {
  d <- wide[[paste0(v, ".C2")]] - wide[[paste0(v, ".C1")]]
  data.frame(participant_id = wide$participant_id, expertise_level = wide$expertise_level,
             first_condition = order_info$first_condition[match(wide$participant_id, order_info$participant_id)],
             measure = measure_labels[[v]], difference = d)
}))
order_split <- split(order_scores, interaction(order_scores$measure, order_scores$first_condition, drop = TRUE))
order_summary <- do.call(rbind, lapply(order_split, function(d) data.frame(
  measure = d$measure[1], first_condition = d$first_condition[1], n = nrow(d),
  mean_difference = mean(d$difference), sd = sd(d$difference))))
write_table(order_summary, "condition_order_questionnaire_differences.csv")

action_summary <- as.data.frame.matrix(table(cases$condition, cases$action))
action_summary$condition <- rownames(action_summary)
write_table(action_summary, "suggestion_actions.csv")

# Supplementary exploratory case-level time contrasts, clearly treated as descriptive.
time_by_condition <- aggregate(cases$time_seconds,
                               list(participant_id = cases$participant_id, condition = cases$condition), mean)
names(time_by_condition)[3] <- "time_seconds"
time_wide <- reshape(time_by_condition, idvar = "participant_id", timevar = "condition", direction = "wide")
time_d <- time_wide$time_seconds.C2 - time_wide$time_seconds.C1
time_test <- if (length(time_d) > 1) t.test(time_wide$time_seconds.C2, time_wide$time_seconds.C1, paired = TRUE) else NULL
time_paired_summary <- data.frame(measure = "Mean time per participant (seconds)", n = length(time_d),
  C1_mean = mean(time_wide$time_seconds.C1), C1_sd = sd(time_wide$time_seconds.C1),
  C2_mean = mean(time_wide$time_seconds.C2), C2_sd = sd(time_wide$time_seconds.C2),
  mean_difference_C2_minus_C1 = mean(time_d), CI95_low = time_test$conf.int[1], CI95_high = time_test$conf.int[2],
  cohens_dz = mean(time_d) / sd(time_d), wilcoxon_V = unname(wilcox.test(time_d, mu = 0, exact = FALSE)$statistic),
  wilcoxon_p = wilcox.test(time_d, mu = 0, exact = FALSE)$p.value,
  decreased = sum(time_d < 0), increased = sum(time_d > 0), unchanged = sum(time_d == 0))
write_table(time_paired_summary, "time_on_task_paired_comparison.csv")

# Figures use condition color consistently and display participant-level points.
if (identical(Sys.getenv("UTA21_DATA_ONLY"), "true")) {
  cat("Data-only analysis complete. Tables written to", table_dir, "\n")
  quit(save = "no", status = 0)
}
p_scores <- ggplot(score_long, aes(condition, score, group = participant_id, color = expertise_level)) +
  geom_line(alpha = .35, linewidth = .45) + geom_point(size = 2.1, position = position_jitter(width = .035, height = 0)) +
  stat_summary(aes(group = condition), fun = mean, geom = "crossbar", width = .52,
               color = "#172B4D", linewidth = .55) +
  facet_wrap(~measure, scales = "free_y", ncol = 2) + scale_color_manual(values = group_cols) +
  labs(title = "Questionnaire scores by condition", subtitle = "Lines connect the same participant; thick bars show condition means.",
       x = NULL, y = "Score", color = "Experience") + theme_uta()
save_plot(p_scores, "questionnaire_scores.png", 9, 7)

forest <- questionnaire_summary
forest$measure <- factor(forest$measure, levels = rev(forest$measure))
p_forest <- ggplot(forest, aes(mean_difference_C2_minus_C1, measure)) +
  geom_vline(xintercept = 0, color = "#8A97A8", linetype = 2) +
  geom_errorbar(aes(xmin = CI95_low, xmax = CI95_high), width = .18, color = "#2878B5", linewidth = .7) +
  geom_point(size = 2.7, color = "#2878B5") +
  labs(title = "Paired questionnaire differences", subtitle = "C2 minus C1; points are means and bars are 95% paired t confidence intervals.",
       x = "Mean paired difference", y = NULL) + theme_uta()
save_plot(p_forest, "questionnaire_paired_differences.png", 9, 5.5)

time_long <- cases
time_long$block_label <- factor(time_long$block, levels = c(1, 2), labels = c("First block", "Second block"))
p_time <- ggplot(time_long, aes(condition, time_seconds, fill = condition)) +
  geom_boxplot(width = .5, alpha = .45, outlier.shape = NA, color = "#26364A") +
  geom_point(aes(color = condition), position = position_jitter(width = .08, height = 0), alpha = .72, size = 2) +
  facet_wrap(~expertise_level, labeller = as_labeller(c(expert = "Experts", novice = "Novices"))) +
  scale_fill_manual(values = condition_cols) + scale_color_manual(values = condition_cols) +
  labs(title = "Time on task by condition and experience", subtitle = "Each point is one case observation; seconds.",
       x = NULL, y = "Time on task (seconds)") + theme_uta() + theme(legend.position = "none")
save_plot(p_time, "time_on_task.png", 8.2, 4.8)

p_block <- ggplot(time_long, aes(block_label, time_seconds, fill = condition)) +
  geom_boxplot(position = position_dodge(width = .72), width = .6, alpha = .6, outlier.shape = NA) +
  geom_point(aes(color = condition), position = position_jitterdodge(jitter.width = .08, dodge.width = .72),
             alpha = .6, size = 1.7) + scale_fill_manual(values = condition_cols) +
  scale_color_manual(values = condition_cols) +
  labs(title = "Time on task by block and condition", subtitle = "Block assignment follows the observed row order within participant.",
       x = NULL, y = "Time on task (seconds)") + theme_uta()
save_plot(p_block, "time_by_block.png", 8.2, 4.8)

agreement_long <- rbind(
  data.frame(condition = cases$condition, expertise_level = cases$expertise_level,
             measure = "Exact BI-RADS", agreed = as.integer(cases$exact_agreement)),
  data.frame(condition = cases$condition, expertise_level = cases$expertise_level,
             measure = "Suspicion band", agreed = as.integer(cases$band_agreement)))
agreement_long <- agreement_long[!(agreement_long$measure == "Suspicion band" & cases$participant_zero), ]
p_agreement <- ggplot(agreement_long, aes(condition, agreed, color = expertise_level)) +
  geom_jitter(width = .1, height = .035, alpha = .42, size = 1.6) +
  stat_summary(aes(group = interaction(condition, expertise_level)), fun = mean, geom = "point",
               shape = 18, size = 4, position = position_dodge(width = .34)) +
  facet_wrap(~measure) + scale_color_manual(values = group_cols) + scale_y_continuous(breaks = c(0, 1), labels = c("No", "Yes"), limits = c(-.1, 1.1)) +
  labs(title = "Assistant-participant agreement", subtitle = "Band agreement excludes participant BI-RADS 0 responses.",
       x = NULL, y = "Agreement", color = "Experience") + theme_uta()
save_plot(p_agreement, "birads_agreement.png", 8.2, 4.8)

cat("Analysis complete. Outputs written to", out_dir, "\n")
