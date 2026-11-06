# Extra inference for the single-post-season problem (exploratory; added after the main analysis).
#
# 1. Placebo-year (permutation) test. Each pre season Y in 2018-2024 is treated as a fake rule year and
#    compared with the other pre seasons (2025 data never used). The real estimate compares 2025 with all
#    of 2018-2024, so all eight estimates share one design. This shows how much the NFL-minus-college gap
#    moves in an ordinary year, which game-clustered SEs ignore (they treat season-wide shocks as signal).
#    With 7 placebo years the smallest possible permutation p-value is 1/8 = 0.125.
# 2. Game-cluster bootstrap of the main DiD (2021-24 vs 2025): resample games with replacement within
#    each league-season, refit, and take percentile CIs. Checks the analytic (delta-method) CIs.
#
# Outputs: outputs/tables/inference_*.csv, outputs/figures/fig11_placebo_years.png,
#          outputs/inference_report.md
# Usage: Rscript --vanilla src/07_inference.R [bootstrap_reps]

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
tables_dir <- file.path(root, "outputs", "tables")
figs_dir <- file.path(root, "outputs", "figures")
source(file.path(script_dir, "model_setup.R"))
source(file.path(script_dir, "plot_style.R"))
set.seed(327)
args <- as.integer(commandArgs(trailingOnly = TRUE))
B <- if (length(args) == 1) args else 999L

# ---------------------------------------------------------------------------- 1. Placebo years
pre_all <- 2018:2024
placebo_rows <- list()
for (o in outcome_specs) {
  base <- if (o$src == "fg") fg_all[season %in% 2018:2025] else in_universe(fd_all[season %in% 2018:2025])
  for (yr in c(pre_all, 2025)) {
    d <- if (yr == 2025) copy(base) else base[season %in% pre_all]
    d[, treat := as.integer(nfl == 1 & season == yr)]
    r <- did(o$y, d, o$ctrl, fam_of(o), label = o$label, spec = as.character(yr))
    placebo_rows[[length(placebo_rows) + 1]] <- r[, .(okey = o$key, outcome, year = yr,
                                                      type = fifelse(yr == 2025, "actual", "placebo"),
                                                      estimate, se, ci_lo, ci_hi, unit)]
  }
}
placebo <- rbindlist(placebo_rows)
fwrite(placebo, file.path(tables_dir, "inference_placebo_years.csv"))

perm <- placebo[, {
  act <- estimate[type == "actual"]
  plc <- estimate[type == "placebo"]
  plc_no20 <- estimate[type == "placebo" & year != 2020]
  .(actual = act, actual_se_clustered = se[type == "actual"],
    placebo_sd = sd(plc), placebo_mean_abs = mean(abs(plc)),
    mean_clustered_se_placebo = mean(se[type == "placebo"]),
    rank_abs = sum(abs(c(plc, act)) >= abs(act)),      # 1 = largest of the 8
    perm_p = mean(abs(c(plc, act)) >= abs(act)),
    perm_p_excl_2020 = mean(abs(c(plc_no20, act)) >= abs(act)),
    season_noise_ci_lo = act - 1.96 * sd(plc), season_noise_ci_hi = act + 1.96 * sd(plc))
}, by = .(okey, outcome, unit)]
perm[, se_ratio := placebo_sd / mean_clustered_se_placebo]
fwrite(perm, file.path(tables_dir, "inference_placebo_summary.csv"))

# ---------------------------------------------------------------------------- 2. Game-cluster bootstrap
boot_ame <- function(o, d) {
  fml <- as.formula(sprintf("%s ~ treat + factor(season) + %s", o$y, o$ctrl))
  if (fam_of(o) == "linear") return(coef(feols(fml, d, vcov = "iid"))[["treat"]])
  m <- feglm(fml, d, family = binomial(), vcov = "iid")
  nd1 <- d[treat == 1]; nd0 <- copy(nd1)[, treat := 0L]
  mean(predict(m, newdata = nd1) - predict(m, newdata = nd0)) * 100
}
boot_rows <- list(); boot_draws <- list()
for (o in outcome_specs) {
  d <- get_sample(o, 2021:2024)
  games <- unique(d[, .(league, season, game_id)])
  point <- boot_ame(o, d)
  draws <- vapply(seq_len(B), function(b) {
    idx <- games[, .(game_id = sample(game_id, .N, replace = TRUE)), by = .(league, season)]
    bd <- d[idx, on = .(league, season, game_id), allow.cartesian = TRUE]
    tryCatch(boot_ame(o, bd), error = function(e) NA_real_)
  }, numeric(1))
  boot_draws[[o$key]] <- data.table(okey = o$key, draw = draws)
  boot_rows[[length(boot_rows) + 1]] <- data.table(
    okey = o$key, outcome = o$label, unit = if (o$y == "kick_distance") "yds" else "pp",
    estimate = point, boot_se = sd(draws, na.rm = TRUE),
    boot_ci_lo = quantile(draws, 0.025, na.rm = TRUE), boot_ci_hi = quantile(draws, 0.975, na.rm = TRUE),
    boot_p = min(1, 2 * min(mean(draws <= 0, na.rm = TRUE), mean(draws >= 0, na.rm = TRUE))),
    reps_ok = sum(!is.na(draws)), reps = B)
}
boot <- rbindlist(boot_rows)
main <- fread(file.path(tables_dir, "model_main_did.csv"))
boot <- cbind(boot, main[, .(analytic_ci_lo = ci_lo, analytic_ci_hi = ci_hi, analytic_p = p)])
fwrite(boot, file.path(tables_dir, "inference_bootstrap.csv"))
fwrite(rbindlist(boot_draws), file.path(tables_dir, "inference_bootstrap_draws.csv"))

# ---------------------------------------------------------------------------- Figure
pd <- copy(placebo)
pd[, panel := factor(sprintf("%s (%s)", outcome, unit), levels = unique(sprintf("%s (%s)", outcome, unit)))]
pd[, type := factor(type, levels = c("actual", "placebo"))]
type_cols <- c(actual = league_colors[["NFL"]], placebo = "#9a9893")
p11 <- ggplot(pd, aes(year, estimate, colour = type)) +
  geom_hline(yintercept = 0, colour = ink_2, linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0, linewidth = 0.6) +
  geom_point(size = 2.4) +
  facet_wrap(~panel, scales = "free_y", ncol = 3) +
  scale_colour_manual(values = type_cols, breaks = c("actual", "placebo"),
                      labels = c("2025 (actual rule year)", "Placebo: earlier season treated as a fake rule year")) +
  scale_x_continuous(breaks = 2018:2025) +
  labs(title = "Is 2025 unusual? NFL-minus-college gap in the rule year vs ordinary years",
       subtitle = "Each point: that season vs the other pre-2025 seasons (2025: vs all of 2018-24). Bars = game-clustered 95% CI.",
       x = NULL, y = "NFL-specific change", caption = "2020 = COVID season. 2025 data is never used in the placebo estimates.") +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9), axis.text.x = element_text(size = 7.5),
        strip.text = element_text(size = 9.5), panel.spacing = unit(1.2, "lines"))
save_fig(p11, file.path(figs_dir, "fig11_placebo_years.png"), width = 11, height = 6.4)

# ---------------------------------------------------------------------------- Report
f2 <- function(x) formatC(x, digits = 2, format = "f")
f3 <- function(x) formatC(x, digits = 3, format = "f")
ord <- sapply(outcome_specs, `[[`, "key")
perm <- perm[match(ord, okey)]; boot <- boot[match(ord, okey)]
wide <- dcast(placebo, outcome + unit ~ year, value.var = "estimate")[match(sapply(outcome_specs, `[[`, "label"), outcome)]
num <- setdiff(names(wide), c("outcome", "unit"))
wide[, (num) := lapply(.SD, function(x) round(x, 2)), .SDcols = num]
report <- c(
  "# Extra inference: placebo years and bootstrap", "",
  "Generated by `src/07_inference.R`. Exploratory: added after the main analysis to address the single post season.", "",
  "## 1. Placebo-year (permutation) test", "",
  "Each season 2018-2024 is treated as a fake rule year and compared with the other pre-2025 seasons; 2025 is",
  "compared with all of 2018-2024. If 2025 had a real NFL-specific effect, its estimate should stand out from the",
  "ordinary-year estimates. With 7 placebo years the smallest possible permutation p-value is 0.125.", "",
  "Estimates by year (NFL-specific change):", "", kable(wide, format = "pipe"), "",
  kable(perm[, .(outcome, unit, `2025 estimate` = f2(actual), `rank of abs(2025) among 8` = rank_abs,
                 `perm p` = f3(perm_p), `perm p excl. 2020` = f3(perm_p_excl_2020),
                 `SD across placebo years` = f2(placebo_sd), `avg clustered SE` = f2(mean_clustered_se_placebo),
                 `SD / SE` = f2(se_ratio),
                 `2025 +/- 1.96 x placebo SD` = sprintf("[%s, %s]", f2(season_noise_ci_lo), f2(season_noise_ci_hi)))],
        format = "pipe"), "",
  "`SD / SE` above 1 means estimates move more from season to season than game-clustered SEs assume, i.e.",
  "season-wide shocks exist and the analytic CIs are too narrow; the placebo-based interval is then the more honest one.", "",
  sprintf("## 2. Game-cluster bootstrap of the main DiD (%d reps, resampling games within league-season)", B), "",
  kable(boot[, .(outcome, unit, estimate = f2(estimate),
                 `bootstrap 95% CI` = sprintf("[%s, %s]", f2(boot_ci_lo), f2(boot_ci_hi)), `bootstrap p` = f3(boot_p),
                 `analytic 95% CI` = sprintf("[%s, %s]", f2(analytic_ci_lo), f2(analytic_ci_hi)), `analytic p` = f3(analytic_p),
                 `reps ok` = reps_ok)], format = "pipe"), "")
writeLines(report, file.path(root, "outputs", "inference_report.md"))
cat(report, sep = "\n")
