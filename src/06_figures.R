# Result figures (step 6) from the model tables written by 05_models.R.
# Usage: Rscript --vanilla src/06_figures.R

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
source(file.path(script_dir, "plot_style.R"))
tables_dir <- file.path(root, "outputs", "tables")
figs_dir <- file.path(root, "outputs", "figures")
rd <- function(f) fread(file.path(tables_dir, f))

# ---------------------------------------------------------------------------- fig7: each league's own change
lp <- rd("model_league_prepost.csv")
lp <- lp[outcome != "FG made (raw)"]
lp[, panel := factor(sprintf("%s (%s)", outcome, unit),
                     levels = c("FG made (distance-adjusted) (pp)", "Attempt distance (yds)", "Share of attempts 50+ yds (pp)"))]
lp[, league := factor(league, levels = c("NCAA", "NFL"))]
p7 <- ggplot(lp, aes(estimate, league, colour = league)) +
  geom_vline(xintercept = 0, colour = ink_2, linewidth = 0.4) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0, orientation = "y", linewidth = 0.9) +
  geom_point(size = 3) +
  geom_text(aes(label = sprintf("%+.1f", estimate)), vjust = -1, size = 3.2, colour = ink) +
  facet_wrap(~panel, scales = "free_x") +
  scale_colour_manual(values = league_colors, labels = league_labels, breaks = c("NFL", "NCAA"), guide = "none") +
  scale_y_discrete(labels = league_labels) +
  labs(title = "2025 vs 2021-24: the NFL improved, but so did college",
       subtitle = "Each league's own change with 95% CI. The K-ball effect is the NFL change minus the college change.",
       x = NULL, y = NULL, caption = "Logit / linear models, SEs clustered by game. Regular season; college = FBS vs FBS.") +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9), panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.4),
        axis.text.y = element_text(colour = ink, size = 10), panel.spacing = unit(1.5, "lines"))
save_fig(p7, file.path(figs_dir, "fig7_league_change_2025.png"), width = 10.5, height = 3.6)

# ---------------------------------------------------------------------------- fig8: DiD estimates + robustness
rb <- rd("model_robustness.csv")
outcome_order <- c("FG made (distance-adjusted)", "Attempt distance", "Share of attempts 50+ yds",
                   "Kick on 4th down (FG range, <=5 to go)", "Go for it on 4th down (FG range, <=5 to go)")
rb[, panel := factor(sprintf("%s (%s)", outcome, unit), levels = unique(sprintf("%s (%s)", outcome, unit)[order(match(outcome, outcome_order))]))]
spec_order <- unique(rb$spec)
rb[, spec := factor(spec, levels = rev(spec_order))]
rb[, kind := fcase(spec == "Main: 2021-24 vs 2025", "Main estimate",
                   grepl("^Placebo|^Exploratory", spec), "Placebo / exploratory",
                   default = "Robustness check")]
kind_cols <- c(`Main estimate` = league_colors[["NFL"]], `Robustness check` = "#7aa5df",
               `Placebo / exploratory` = ink_2)
p8 <- ggplot(rb, aes(estimate, spec, colour = kind)) +
  geom_vline(xintercept = 0, colour = ink_2, linewidth = 0.4) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0, orientation = "y", linewidth = 0.6) +
  geom_point(size = 2.2) +
  facet_grid(. ~ panel, scales = "free_x", labeller = label_wrap_gen(width = 24)) +
  scale_colour_manual(values = kind_cols, breaks = names(kind_cols)) +
  labs(title = "NFL-specific 2025 effect (difference-in-differences) across specifications",
       subtitle = "Effect on NFL 2025 plays relative to the change in college, 95% CI. Zero = no NFL-specific change.",
       x = NULL, y = NULL,
       caption = paste("Blank = check does not apply to that outcome. Placebo pretends the rule started in 2024",
                       "(pre-period data only). 2026 = partial season, same weeks each year.")) +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9), panel.grid.major.y = element_line(colour = "#f1f0ed", linewidth = 0.3),
        panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.4),
        axis.text.y = element_text(size = 8.5, colour = ink), axis.text.x = element_text(size = 8),
        strip.text = element_text(size = 9, vjust = 0), panel.spacing = unit(1.1, "lines"))
save_fig(p8, file.path(figs_dir, "fig8_did_robustness.png"), width = 14, height = 5.2)

# ---------------------------------------------------------------------------- fig9: accuracy effect by distance bin
bb <- rd("model_did_by_bin.csv")
bb[, dbin := factor(dbin, levels = c("<40", "40-49", "50-59", "60+"))]
bb[, n_lab := sprintf("%s\nNFL %d / %d\ncollege %d / %d", dbin, nfl_pre, nfl_2025, college_pre, college_2025)]
bb[, n_lab := factor(n_lab, levels = n_lab[order(dbin)])]
p9 <- ggplot(bb, aes(n_lab, estimate)) +
  geom_hline(yintercept = 0, colour = ink_2, linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0, colour = league_colors[["NFL"]], linewidth = 0.9) +
  geom_point(size = 3, colour = league_colors[["NFL"]]) +
  geom_text(aes(label = sprintf("%+.1f", estimate)), hjust = -0.4, size = 3.2, colour = ink) +
  labs(title = "NFL-specific 2025 accuracy effect by attempt distance",
       subtitle = "Percentage points, 95% CI. 60+ is too rare (22 NFL and 7 college attempts in 2025) to estimate.",
       x = "Attempt distance (yards); attempts 2021-24 / 2025", y = "Effect on make rate (pp)") +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9), axis.text.x = element_text(size = 8))
save_fig(p9, file.path(figs_dir, "fig9_did_by_distance.png"), width = 8, height = 4.6)

# ---------------------------------------------------------------------------- fig10: within-kicker
wk <- rd("model_within_kicker_per_kicker_min15.csv")
long <- rbind(
  wk[, .(name, measure = "FG% over expected (pp)", pre = fgoe_pre, post = fgoe_post)],
  wk[, .(name, measure = "Mean attempt distance (yds)", pre = mean_dist_pre, post = mean_dist_post)])
long[, measure := factor(measure, levels = c("FG% over expected (pp)", "Mean attempt distance (yds)"))]
lims <- long[, .(lo = min(pre, post), hi = max(pre, post)), by = measure]
diag_d <- lims[, .(x = c(lo, hi), y = c(lo, hi)), by = measure]
p10 <- ggplot(long, aes(pre, post)) +
  geom_line(data = diag_d, aes(x, y), colour = ink_2, linetype = "dashed", linewidth = 0.4) +
  geom_point(colour = league_colors[["NFL"]], size = 2.4, alpha = 0.85) +
  facet_wrap(~measure, scales = "free") +
  labs(title = "Same NFL kickers, 2021-24 vs 2025",
       subtitle = sprintf("%d kickers with 15+ attempts in both periods. Above the dashed line = higher in 2025.", nrow(wk)),
       x = "2021-24", y = "2025",
       caption = "Expected make rate from the NFL 2021-24 distance curve. Survivors only: kickers who stayed in the league.") +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9),
        panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.4), panel.spacing = unit(1.5, "lines"))
save_fig(p10, file.path(figs_dir, "fig10_within_kicker.png"), width = 9.5, height = 4.6)

cat("figures written\n")
