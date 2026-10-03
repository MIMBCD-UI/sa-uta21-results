#!/usr/bin/env Rscript
# =============================================================================
# Conventions
#   - C1 = Clinical-First, C2 = Regulatory-First.
#   - Paired differences are C2 minus C1.
#   - Suspicion levels: Low = {1,2}, Moderate = {3,4}, High = {5}.
#   - A final assessment of BI-RADS 0 falls within no level; band agreement is
#     reported both excluding such responses and counting them as departures.
#   - Block order is taken from row order in the case file (first three rows of
#     a participant = first block).
#   - SUS: standard scoring (odd items x-1, even items 5-x, sum x 2.5).
#   - NASA-TLX: six items on 1-10; the performance item is reverse-scored
#     (11-x); the composite is the mean of the six.
#   - TiA: Koerber (2019) key; items 5, 7, 10, 15, 16 reverse-scored (6-x).
#   - Wilcoxon signed-rank test: zero differences dropped, exact p-value from
#     the permutation distribution of the (mid)ranks. Differences are rounded
#     to 10 decimals before ranking, so that differences of equal magnitude
#     (e.g. +5/6 and -5/6 on NASA-TLX) tie exactly despite floating-point
#     error. R's default wilcox.test would instead use a normal approximation
#     here because of ties and zeros.
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
case_csv  <- if (length(args) >= 1) args[1] else "data/mimbcdui_uta21_case_data.csv"
quest_csv <- if (length(args) >= 2) args[2] else "data/mimbcdui_uta21_questionnaire_answers.csv"

two_modality_cases <- c("c01", "c02", "c05", "c07")  # all other cases have 3

# TiA subscales, item numbers (Koerber, TiA manual, Table 1)
tia_subscales <- list(
  "Reliability/Competence"       = c(1, 6, 10, 13, 15, 19),
  "Understanding/Predictability" = c(2, 7, 11, 16),
  "Familiarity"                  = c(3, 17),
  "Intention of Developers"      = c(4, 8),
  "Propensity to Trust"          = c(5, 12, 18),
  "Trust in Automation"          = c(9, 14)
)
tia_reversed <- c(5, 7, 10, 15, 16)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section <- function(title) {
  cat("\n", strrep("=", 78), "\n", title, "\n", strrep("=", 78), "\n", sep = "")
}

pct <- function(a, n) {
  if (n > 0) sprintf("%d/%d (%.1f%%)", as.integer(a), as.integer(n), 100 * a / n) else "0/0"
}

level_of <- function(b) {
  out <- rep(NA_character_, length(b))
  out[b %in% c(1, 2)] <- "Low"
  out[b %in% c(3, 4)] <- "Moderate"
  out[b == 5] <- "High"
  out[b == 0] <- "0"
  out[b == 6] <- "6"
  out
}

to_seconds <- function(x) {
  parts <- strsplit(trimws(as.character(x)), ":")
  sapply(parts, function(p) sum(as.numeric(p) * c(3600, 60, 1)))
}

summ <- function(x) {
  round(c(n = length(x), mean = mean(x), median = median(x), sd = sd(x)), 1)
}

band_report <- function(df, label) {
  cat("\n", label, "\n", sep = "")
  for (cond in c("C1", "C2")) {
    d <- df[df$cond == cond, ]
    nz <- d[!d$zero, ]
    cat(sprintf("  %s: band excl. BI-RADS 0 %s | band, 0 as departure %s | exact %s | exact excl. BI-RADS 0 %s\n",
                cond,
                pct(sum(nz$band), nrow(nz)),
                pct(sum(d$band), nrow(d)),
                pct(sum(d$exact), nrow(d)),
                pct(sum(nz$exact), nrow(nz))))
  }
}

rank_biserial <- function(d) {
  d <- d[d != 0]
  if (length(d) == 0) return(NA_real_)
  r <- rank(abs(d))
  (sum(r[d > 0]) - sum(r[d < 0])) / sum(r)
}

wilcoxon_exact <- function(d) {
  d <- d[d != 0]
  n <- length(d)
  if (n == 0) return(c(W = 0, p = 1))
  r <- rank(abs(d))
  w_obs <- min(sum(r[d > 0]), sum(r[d < 0]))
  signs <- as.matrix(expand.grid(rep(list(c(0, 1)), n)))
  w_all <- as.vector(signs %*% r)
  c(W = w_obs, p = min(1, 2 * mean(w_all <= w_obs + 1e-9)))
}

paired_row <- function(name, a, b) {
  d <- round(b - a, 10)  # rounding makes equal magnitudes tie exactly
  n <- length(d)
  m <- mean(d)
  s <- sd(d)
  half <- qt(0.975, n - 1) * s / sqrt(n)
  w <- wilcoxon_exact(d)
  data.frame(measure   = name,
             M_diff    = round(m, 2),
             CI_low    = round(m - half, 2),
             CI_high   = round(m + half, 2),
             d_z       = round(m / s, 2),
             r_rb      = round(rank_biserial(d), 2),
             W         = unname(w["W"]),
             p         = round(unname(w["p"]), 3),
             decreased = sum(d < 0),
             increased = sum(d > 0),
             unchanged = sum(d == 0),
             check.names = FALSE, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Case data
# ---------------------------------------------------------------------------
cd <- read.csv(case_csv, check.names = FALSE, strip.white = TRUE,
               stringsAsFactors = FALSE)
cd <- cd[, 1:9]
names(cd) <- trimws(names(cd))
cd$cond       <- ifelse(cd$condition == 1, "C1", "C2")
cd$tot        <- to_seconds(cd$time_on_task)
cd$block      <- (ave(seq_len(nrow(cd)), cd$participant_id, FUN = seq_along) - 1) %/% 3 + 1
cd$level_a    <- level_of(cd$birads_assistant)
cd$level_r    <- level_of(cd$birads_radiologist)
cd$exact      <- cd$birads_assistant == cd$birads_radiologist
cd$band       <- cd$level_a == cd$level_r
cd$zero       <- cd$birads_radiologist == 0
cd$repeat_obs <- duplicated(paste(cd$participant_id, cd$case_id))
cd$n_mod      <- ifelse(cd$case_id %in% two_modality_cases, 2, 3)

first_rows <- cd[cd$block == 1, ]
first_cond <- tapply(first_rows$cond, first_rows$participant_id, function(x) x[1])

section("6.1 Realized sample and allocation")
cat("Observations:", nrow(cd),
    "| repeats:", sum(cd$repeat_obs),
    "| repeats in second block:", sum(cd$repeat_obs & cd$block == 2), "\n")
cat("\nRepeated observations:\n")
print(cd[cd$repeat_obs, c("participant_id", "cond", "case_id")], row.names = FALSE)
cat("\nCondition completed first:\n")
print(first_cond)
cat("\nCondition completed first, by experience group:\n")
print(table(group = tapply(cd$expertise_level, cd$participant_id, `[`, 1)[names(first_cond)],
            began = first_cond))
cat("\nCase mix by suspicion level\n")
print(table(cd$cond, factor(cd$level_a, levels = c("Low", "Moderate", "High"))))
cat("\nObservations on cases with all three modalities:\n")
print(table(cd$cond[cd$n_mod == 3]))

section("6.2.4 Time on task (seconds)")
print(t(sapply(split(cd$tot, cd$cond), summ)))
print(t(sapply(split(cd$tot, cd$block), summ)))
cat("\nBy number of modalities:\n")
print(t(sapply(split(cd$tot, cd$n_mod), summ)))
print(round(tapply(cd$tot, list(modalities = cd$n_mod, cond = cd$cond), mean), 1))
cat("\nBy experience group:\n")
print(round(tapply(cd$tot, list(group = cd$expertise_level, cond = cd$cond), mean), 1))

section("6.2.5 Concordance with the assistant")
band_report(cd, "All observations")
band_report(cd[!cd$repeat_obs, ], "Excluding repeated observations")
dep <- cd[!cd$exact & !cd$zero, ]
dep$direction <- ifelse(dep$birads_radiologist > dep$birads_assistant, "up", "down")
cat("\nDirection of departures (excluding BI-RADS 0):\n")
print(table(dep$cond, dep$direction))

section("6.3.4 Concordance by experience group")
cat("Exact agreement per participant:\n")
print(round(tapply(cd$exact, list(participant = cd$participant_id, cond = cd$cond), mean), 2))
for (g in c("expert", "novice")) {
  band_report(cd[cd$expertise_level == g, ], paste("Group:", g))
}

section("6.4 Concordance by suspicion level")
for (lvl in c("Low", "Moderate", "High")) {
  band_report(cd[cd$level_a == lvl, ], paste("Level:", lvl))
  band_report(cd[cd$level_a == lvl & !cd$repeat_obs, ],
              paste("Level:", lvl, "(excluding repeats)"))
}
cat("\nModerate cases, per case (band agreement, excluding BI-RADS 0):\n")
m <- cd[cd$level_a == "Moderate" & !cd$zero, ]
print(tapply(m$band, list(case = m$case_id, cond = m$cond),
             function(x) sprintf("%d/%d", sum(x), length(x))))
cat("\nModerate observations in detail:\n")
mm <- cd[cd$level_a == "Moderate",
         c("participant_id", "cond", "block", "case_id",
           "birads_assistant", "birads_radiologist", "repeat_obs")]
print(mm[order(mm$case_id, mm$cond), ], row.names = FALSE)

section("6.4.2 BI-RADS 0 responses")
print(cd[cd$zero, c("participant_id", "expertise_level", "cond", "case_id",
                    "birads_assistant", "n_mod")], row.names = FALSE)

# ---------------------------------------------------------------------------
# Questionnaires
# ---------------------------------------------------------------------------
q <- read.csv(quest_csv, skip = 1, check.names = FALSE, strip.white = TRUE,
              stringsAsFactors = FALSE)
names(q) <- trimws(names(q))
q <- q[!is.na(q$condition), ]
q$cond <- ifelse(q$condition == 1, "C1", "C2")

sus <- as.matrix(q[, 6:15])
tlx <- as.matrix(q[, 16:21])
tia <- as.matrix(q[, 22:40])
stopifnot(ncol(sus) == 10, ncol(tlx) == 6, ncol(tia) == 19)

q$SUS <- (rowSums(sus[, c(1, 3, 5, 7, 9)] - 1) + rowSums(5 - sus[, c(2, 4, 6, 8, 10)])) * 2.5
tlx[, 4] <- 11 - tlx[, 4]  # performance item reverse-scored
q[["NASA-TLX"]] <- rowMeans(tlx)
tia[, tia_reversed] <- 6 - tia[, tia_reversed]
for (nm in names(tia_subscales)) {
  q[[nm]] <- rowMeans(tia[, tia_subscales[[nm]], drop = FALSE])
}
measures <- c("SUS", "NASA-TLX", names(tia_subscales))
grp <- tapply(q$expertise_level, q$participant_id, function(x) x[1])

by_cond <- function(var) {
  c1 <- q[q$cond == "C1", c("participant_id", var)]
  c2 <- q[q$cond == "C2", c("participant_id", var)]
  mrg <- merge(c1, c2, by = "participant_id")
  data.frame(participant_id = mrg[[1]], C1 = mrg[[2]], C2 = mrg[[3]],
             stringsAsFactors = FALSE)
}

section("6.2.1-6.2.3 Questionnaire means by condition")
print(round(t(sapply(measures, function(v) tapply(q[[v]], q$cond, mean))), 2))
for (v in c("SUS", "NASA-TLX")) {
  cat("\nPer participant:", v, "\n")
  w <- by_cond(v)
  w$C1 <- round(w$C1, 2)
  w$C2 <- round(w$C2, 2)
  print(w, row.names = FALSE)
}

section("6.2.7 Paired differences (C2 minus C1), n = 8")
tot_pp <- aggregate(tot ~ participant_id + cond, data = cd, FUN = mean)
tot_c1 <- tot_pp[tot_pp$cond == "C1", ]
tot_c2 <- tot_pp[tot_pp$cond == "C2", ]
tot_c2 <- tot_c2[match(tot_c1$participant_id, tot_c2$participant_id), ]
rows <- list(paired_row("Time on task (s)", tot_c1$tot, tot_c2$tot))
for (v in measures) {
  w <- by_cond(v)
  rows[[length(rows) + 1]] <- paired_row(v, w$C1, w$C2)
}
print(do.call(rbind, rows), row.names = FALSE)

diffs <- data.frame(participant_id = by_cond("SUS")$participant_id,
                    stringsAsFactors = FALSE)
for (v in measures) {
  w <- by_cond(v)
  diffs[[v]] <- w$C2 - w$C1
}
cat("\nExcluding P6 (mean paired difference):\n")
print(round(colMeans(diffs[diffs$participant_id != "P6", measures]), 2))

section("6.2.6 Paired differences by condition completed first")
diffs$began <- as.vector(first_cond[diffs$participant_id])
zero_small <- function(x) { x[abs(x) < 1e-9] <- 0; x }  # avoid printing -0.00
for (b in c("C1", "C2", "All")) {
  sel <- if (b == "All") rep(TRUE, nrow(diffs)) else diffs$began == b
  cat(sprintf("Began with %-3s (n = %d): SUS %7.2f | NASA-TLX %5.2f | Trust in Automation %5.2f\n",
              b, sum(sel),
              zero_small(mean(diffs$SUS[sel])),
              zero_small(mean(diffs[["NASA-TLX"]][sel])),
              zero_small(mean(diffs[["Trust in Automation"]][sel]))))
}

section("6.3 By experience group")
grp_means <- t(sapply(measures, function(v) {
  mt <- tapply(q[[v]], list(q$expertise_level, q$cond), mean)
  c(expert_C1 = mt["expert", "C1"], expert_C2 = mt["expert", "C2"],
    novice_C1 = mt["novice", "C1"], novice_C2 = mt["novice", "C2"])
}))
print(round(grp_means, 2))
cat("\nPer-participant paired differences:\n")
diffs$group <- as.vector(grp[diffs$participant_id])
ord <- order(diffs$group, diffs$participant_id)
out <- cbind(diffs[ord, c("participant_id", "group")], round(diffs[ord, measures], 2))
print(out, row.names = FALSE)

# ---------------------------------------------------------------------------
# Figures
# ---------------------------------------------------------------------------
section("Figures")
out_dir <- if (length(args) >= 3) args[3] else "output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

ink       <- "#0b0b0b"  # primary text
ink2      <- "#52514e"  # secondary text
muted     <- "#898781"  # axis titles
grid_col  <- "#e1e0d9"  # gridlines
axis_col  <- "#c3c2b7"  # axis lines
level_bg  <- "#f0efec"  # neutral fill for suspicion-level blocks
accent    <- "#2a78d6"  # single-series colour
col_grp   <- c(expert = "#2a78d6", novice = "#eb6834")
count_ramp <- c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95")

open_fig <- function(name, width, height) {
  pdf(file.path(out_dir, name), width = width, height = height,
      pointsize = 9, family = "Helvetica", useDingbats = FALSE)
  par(fg = axis_col)  # axis lines and ticks; also resets col, so set col after
  par(col = ink, col.axis = ink2, col.lab = muted, col.main = ink,
      las = 1, tcl = -0.2, mgp = c(1.8, 0.45, 0))
}
close_fig <- function(name) {
  invisible(dev.off())
  cat("Wrote", file.path(out_dir, name), "\n")
}
pid_num <- function(ids) as.numeric(sub("^P", "", ids))

# --- Figure 1: dumbbell chart, one row per participant ------------------------
# Rows: experts on top, novices below. Hollow dot = C1, filled dot = C2;
# a ring around a filled dot marks an unchanged score.
ids_by_grp <- function(g) {
  ids <- names(grp)[grp == g]
  ids[order(pid_num(ids))]
}
row_ids <- c(ids_by_grp("expert"), ids_by_grp("novice"))
n_exp   <- length(ids_by_grp("expert"))
row_y   <- c(seq(10, by = -1, length.out = n_exp),
             seq(10 - n_exp - 1, by = -1, length.out = length(row_ids) - n_exp))
row_grp <- as.vector(grp[row_ids])
gap_y   <- min(row_y[row_grp == "expert"]) - 1

dumbbell_panel <- function(var, xlim, ticks, title, show_ids) {
  w <- by_cond(var)
  w <- w[match(row_ids, w$participant_id), ]
  cols <- unname(col_grp[row_grp])
  plot(NA, xlim = xlim, ylim = c(min(row_y) - 0.7, max(row_y) + 0.7),
       axes = FALSE, xlab = "", ylab = "", yaxs = "i")
  abline(v = ticks, col = grid_col, lwd = 0.6)
  abline(h = row_y, col = grid_col, lwd = 0.4)
  abline(h = gap_y, col = axis_col, lwd = 0.6)
  axis(1, at = ticks, lwd = 0, cex.axis = 0.8)
  if (show_ids) {
    axis(2, at = row_y, labels = row_ids, lwd = 0, cex.axis = 0.85, col.axis = ink)
    mtext(c("Expert", "Novice"), side = 2, line = 3.3, las = 0,
          at = c(mean(row_y[row_grp == "expert"]), mean(row_y[row_grp == "novice"])),
          cex = 0.8, col = ink2, font = 2)
  }
  same <- abs(w$C1 - w$C2) < 1e-9
  segments(w$C1, row_y, w$C2, row_y, col = cols, lwd = 1.8)
  points(w$C1, row_y, pch = 21, bg = "#ffffff", col = cols, cex = 1.15, lwd = 1.2)
  points(w$C2, row_y, pch = 16, col = cols, cex = 1.15)
  points(w$C2[same], row_y[same], pch = 1, col = cols[same], cex = 1.9, lwd = 0.8)
  mtext(title, side = 3, line = 0.5, adj = 0, cex = 0.85, col = ink, font = 2)
}

f1 <- "questionnaires_dumbbell.pdf"
open_fig(f1, width = 6.3, height = 3.1)
layout(matrix(1:3, nrow = 1), widths = c(1.35, 1, 1))
par(oma = c(0, 0, 2, 0))
par(mar = c(2.2, 5, 2, 0.8))
dumbbell_panel("SUS", c(0, 100), seq(0, 100, 20), "Usability (SUS, 0-100)", TRUE)
par(mar = c(2.2, 0.8, 2, 0.8))
dumbbell_panel("NASA-TLX", c(1, 10), seq(2, 10, 2), "Workload (NASA-TLX, 1-10)", FALSE)
par(mar = c(2.2, 0.8, 2, 0.8))
dumbbell_panel("Trust in Automation", c(1, 5), 1:5, "Trust in Automation (1-5)", FALSE)
par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
plot.new()
legend("topleft", legend = c("C1 Clinical-First", "C2 Regulatory-First", "Ring = unchanged"),
       pch = c(21, 16, 1), pt.bg = "#ffffff", pt.cex = c(1.15, 1.15, 1.6),
       col = ink2, horiz = TRUE, bty = "n", text.col = ink2, cex = 0.85,
       inset = c(0.01, 0))
legend("topright", legend = c("Expert", "Novice"), col = col_grp, lwd = 1.8,
       horiz = TRUE, bty = "n", text.col = ink2, cex = 0.85, inset = c(0.01, 0))
close_fig(f1)

# --- Figure 2: forest plot of paired differences -----------------------------
res <- do.call(rbind, rows)
forest_panel <- function(names_in, xlab, show_top = FALSE) {
  d <- res[match(names_in, res$measure), ]
  k <- nrow(d)
  y <- k:1
  xr <- range(c(d$CI_low, d$CI_high, 0))
  xr <- xr + c(-1, 1) * diff(xr) * 0.06
  ticks <- pretty(xr, n = 6)
  plot(NA, xlim = xr, ylim = c(0.4, k + 0.6), axes = FALSE, xlab = "", ylab = "",
       yaxs = "i")
  abline(v = ticks, col = grid_col, lwd = 0.6)
  abline(v = 0, col = ink2, lwd = 0.9)
  axis(1, at = ticks, lwd = 0, cex.axis = 0.8)
  axis(2, at = y, labels = d$measure, lwd = 0, cex.axis = 0.85, col.axis = ink)
  segments(d$CI_low, y, d$CI_high, y, col = accent, lwd = 2, lend = 1)
  points(d$M_diff, y, pch = 16, col = accent, cex = 1.1)
  mtext(xlab, side = 1, line = 1.5, cex = 0.7, col = muted)
}

f2 <- "paired_differences_forest.pdf"
open_fig(f2, width = 6.3, height = 4.2)
layout(matrix(1:4, ncol = 1), heights = c(1, 1, 1, 2.6))
par(mar = c(2.6, 12.5, 0.8, 1.2), oma = c(0, 0, 1.4, 0))
forest_panel("Time on task (s)", "Seconds")
forest_panel("SUS", "SUS points (0-100 scale)")
forest_panel("NASA-TLX", "NASA-TLX points (1-10 scale)")
forest_panel(names(tia_subscales), "TiA points (1-5 scale)")
mtext("Mean paired difference (C2 minus C1) with 95% CI", side = 3, outer = TRUE,
      line = 0.2, adj = 0, cex = 0.85, col = ink, font = 2)
close_fig(f2)

# --- Figure 3: time on task, every observation --------------------------------
f3 <- "time_on_task_boxplot.pdf"
groups <- list(
  list(x = 1, sel = cd$cond == "C1",  lab = "C1"),
  list(x = 2, sel = cd$cond == "C2",  lab = "C2"),
  list(x = 4, sel = cd$block == 1,    lab = "First"),
  list(x = 5, sel = cd$block == 2,    lab = "Second"),
  list(x = 7, sel = cd$n_mod == 2,    lab = "Two"),
  list(x = 8, sel = cd$n_mod == 3,    lab = "Three"),
  list(x = 10, sel = cd$expertise_level == "expert", lab = "Expert"),
  list(x = 11, sel = cd$expertise_level == "novice", lab = "Novice")
)
ymax <- max(cd$tot)
ylim <- c(0, ceiling(ymax / 60) * 60 + 45)
open_fig(f3, width = 6.3, height = 3)
par(mar = c(3.6, 3.4, 1.8, 0.8))
plot(NA, xlim = c(0.3, 11.7), ylim = ylim, axes = FALSE, xlab = "", ylab = "",
     yaxs = "i")
yt <- seq(0, ylim[2] - 45, 60)
abline(h = yt, col = grid_col, lwd = 0.6)
axis(2, at = yt, lwd = 0, cex.axis = 0.85)
mtext("Time on task (s)", side = 2, line = 2.3, las = 0, cex = 0.75, col = muted)
vals <- lapply(groups, function(g) cd$tot[g$sel])
xs   <- sapply(groups, `[[`, "x")
boxplot(vals, at = xs, add = TRUE, axes = FALSE, outline = FALSE, boxwex = 0.6,
        col = count_ramp[1], border = accent, lwd = 0.8,
        medcol = ink, medlwd = 2, whisklty = 1, staplelty = 0)
set.seed(21)  # reproducible horizontal jitter
for (i in seq_along(vals)) {
  v <- vals[[i]]
  points(xs[i] + runif(length(v), -0.2, 0.2), v, pch = 16, cex = 0.8,
         col = adjustcolor(accent, alpha.f = 0.55))
  points(xs[i], mean(v), pch = 23, cex = 1.1, col = ink, bg = "#ffffff")
  text(xs[i], ylim[2] - 20, sprintf("%.1f", mean(v)), cex = 0.72, col = ink2)
}
mtext(sapply(groups, `[[`, "lab"), side = 1, line = 0.5, at = xs,
      cex = 0.75, col = ink)  # mtext never drops labels, unlike axis()
mtext(c("Condition", "Block order", "Modalities available", "Experience"),
      side = 1, line = 2.1, at = c(1.5, 4.5, 7.5, 10.5), cex = 0.75, col = muted)
text(0.3, ylim[2] - 20, "Mean (s)", pos = 2, offset = 0.3, cex = 0.72, col = muted, xpd = NA)
mtext("Time on task per observation: box = median and quartiles, diamond = mean",
      side = 3, line = 0.5, adj = 0, cex = 0.85, col = ink, font = 2)
close_fig(f3)

# --- Figure 4: assistant vs participant BI-RADS ------------------------------
grid_panel <- function(cond, title) {
  d <- cd[cd$cond == cond, ]
  tab <- table(factor(d$birads_radiologist, levels = 0:5),
               factor(d$birads_assistant, levels = 1:5))
  plot(NA, xlim = c(0.5, 5.5), ylim = c(-0.5, 5.5), axes = FALSE, xlab = "",
       ylab = "", xaxs = "i", yaxs = "i")
  # same suspicion level = band agreement
  rect(c(0.5, 2.5, 4.5), c(0.5, 2.5, 4.5), c(2.5, 4.5, 5.5), c(2.5, 4.5, 5.5),
       col = level_bg, border = NA)
  for (r in 0:5) for (a in 1:5) {
    n <- tab[as.character(r), as.character(a)]
    if (n == 0) next
    rect(a - 0.44, r - 0.44, a + 0.44, r + 0.44,
         col = count_ramp[min(n, length(count_ramp))], border = NA)
    text(a, r, n, cex = 0.9, col = if (n >= 4) "#ffffff" else ink)
  }
  axis(1, at = 1:5, lwd = 0, cex.axis = 0.85)
  axis(2, at = 0:5, lwd = 0, cex.axis = 0.85)
  mtext("Assistant BI-RADS", side = 1, line = 1.6, cex = 0.75, col = muted)
  mtext("Participant BI-RADS", side = 2, line = 1.6, las = 0, cex = 0.75, col = muted)
  mtext(sprintf("%s (n = %d)", title, nrow(d)), side = 3, line = 0.5, adj = 0,
        cex = 0.85, col = ink, font = 2)
}

f4 <- "birads_grid.pdf"
open_fig(f4, width = 6.3, height = 3.3)
par(mfrow = c(1, 2), mar = c(3, 3, 2, 1))
grid_panel("C1", "C1 Clinical-First")
grid_panel("C2", "C2 Regulatory-First")
close_fig(f4)