# Parallel-trends check (brief sections 8.6 and 11, step 4).
#
# Uses PRE-PERIOD DATA ONLY (2018-2024); no 2025 data is loaded into any model here, so the
# go/no-go decision for the DiD models cannot be influenced by post-period results.
#
# For each outcome, NFL-minus-college differences are estimated year by year relative to 2024
# (event study), plus a differential linear trend. Standard errors are clustered by game.
#
# Decision rule (fixed before running): pre-trends are flagged as CLEARLY NOT PARALLEL for an
# outcome if, in the primary pre window 2021-2024, the differential linear trend is significant
# (p < 0.05) AND the joint test that all 2018-2023 event-study coefficients are zero rejects
# (p < 0.05). Either test alone rejecting is reported as a WARNING. Failing to reject is not proof
# of parallel trends: with 4-7 pre seasons these tests have limited power.
#
# Outputs: outputs/tables/pretrend_*.csv, outputs/figures/fig6_pretrend_event_study.png,
#          outputs/pretrends_report.md
# Usage: Rscript --vanilla src/04_pretrends.R

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(knitr)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
source(file.path(script_dir, "plot_style.R"))
clean_dir <- file.path(root, "data", "clean")
tables_dir <- file.path(root, "outputs", "tables")
figs_dir <- file.path(root, "outputs", "figures")
ref_year <- 2024

fg <- fread(file.path(clean_dir, "fg_attempts.csv"), colClasses = list(character = c("game_id", "kicker_id")))
fd <- fread(file.path(clean_dir, "fourth_down_decisions.csv"), colClasses = list(character = "game_id"))
fg <- fg[season <= ref_year]
fd <- fd[season <= ref_year]
fg[, `:=`(long50 = as.integer(kick_distance >= 50), season_c = season - ref_year)]

# 4th-down universe for RQ3 (brief 8.4): long FG range (yardline_100 30-55, ~47-72 yd attempts)
# and short-to-medium distance (DECISION: ydstogo <= 5).
fd4 <- fd[yardline_100 >= 30 & yardline_100 <= 55 & ydstogo <= 5]
fd4[, `:=`(kick = as.integer(decision == "kick"), go = as.integer(decision == "go"),
           late = as.integer(game_seconds_remaining < 120), season_c = season - ref_year)]

# Controls are league-specific so each league keeps its own baseline relationship.
dist_ctrl <- "nfl + kick_distance + I(kick_distance^2) + nfl:kick_distance + nfl:I(kick_distance^2)"
fd_ctrl <- paste("nfl + ydstogo + yardline_100 + score_diff + late",
                 "+ nfl:ydstogo + nfl:yardline_100 + nfl:score_diff + nfl:late")

outcomes <- list(
  list(key = "fg_made", label = "FG made (distance-adjusted)", y = "made", data = "fg", ctrl = dist_ctrl,
       unit = "pp", binary = TRUE),
  list(key = "att_dist", label = "Attempt distance", y = "kick_distance", data = "fg", ctrl = "nfl",
       unit = "yds", binary = FALSE),
  list(key = "att_50plus", label = "Share of attempts 50+ yds", y = "long50", data = "fg", ctrl = "nfl",
       unit = "pp", binary = TRUE),
  list(key = "kick_4th", label = "Kick on 4th down (FG range, <=5 to go)", y = "kick", data = "fd4",
       ctrl = fd_ctrl, unit = "pp", binary = TRUE),
  list(key = "go_4th", label = "Go for it on 4th down (FG range, <=5 to go)", y = "go", data = "fd4",
       ctrl = fd_ctrl, unit = "pp", binary = TRUE)
)

windows <- list(all = 2018:2024, primary = 2021:2024, no2020 = setdiff(2018:2024, 2020))

fit <- function(o, years, rhs_key, family) {
  d <- get(o$data)[season %in% years]
  fml <- as.formula(sprintf("%s ~ %s + %s | season", o$y, rhs_key, o$ctrl))
  if (family == "logit") feglm(fml, d, family = binomial(), cluster = ~game_id)
  else feols(fml, d, cluster = ~game_id)
}

es_rows <- list(); test_rows <- list()
for (o in outcomes) {
  scale <- if (o$unit == "pp") 100 else 1
  models <- if (o$binary) c("linear", "logit") else "linear"
  for (fam in models) {
    for (w in names(windows)) {
      yrs <- windows[[w]]
      es <- fit(o, yrs, sprintf("i(season, nfl, ref = %d)", ref_year), fam)
      ct <- coeftable(es)
      es_terms <- grep("^season::", rownames(ct), value = TRUE)
      wj <- wald(es, keep = "^season::", print = FALSE)
      tr <- fit(o, yrs, "nfl:season_c", fam)
      tt <- coeftable(tr)["nfl:season_c", ]
      test_rows[[length(test_rows) + 1]] <- data.table(
        outcome = o$key, label = o$label, model = fam, window = w,
        years = sprintf("%d-%d%s", min(yrs), max(yrs), if (w == "no2020") " excl 2020" else ""),
        n = nobs(es), joint_F = wj$stat, joint_df = wj$df1, joint_p = wj$p,
        trend_per_yr = tt[["Estimate"]] * (if (fam == "linear") scale else 1),
        trend_se = tt[["Std. Error"]] * (if (fam == "linear") scale else 1),
        trend_p = tt[[4]],  # "Pr(>|t|)" for OLS, "Pr(>|z|)" for logit
        trend_unit = if (fam == "linear") paste0(o$unit, "/yr") else "log-odds/yr")
      if (w == "all") {
        es_rows[[length(es_rows) + 1]] <- data.table(
          outcome = o$key, label = o$label, model = fam,
          season = as.integer(sub("^season::(\\d+):nfl$", "\\1", es_terms)),
          estimate = ct[es_terms, "Estimate"] * (if (fam == "linear") scale else 1),
          se = ct[es_terms, "Std. Error"] * (if (fam == "linear") scale else 1),
          unit = if (fam == "linear") o$unit else "log-odds")
      }
    }
  }
}
es_tab <- rbindlist(es_rows)
es_tab <- rbind(es_tab, unique(es_tab[, .(outcome, label, model, unit)])[, `:=`(season = ref_year, estimate = 0, se = 0)],
                use.names = TRUE)
es_tab[, `:=`(ci_lo = estimate - 1.96 * se, ci_hi = estimate + 1.96 * se)]
setorder(es_tab, outcome, model, season)
tests <- rbindlist(test_rows)

# Apply the decision rule (primary window trend + full-window joint test), per outcome and model.
verdict <- merge(
  tests[window == "primary", .(outcome, label, model, trend_per_yr, trend_se, trend_p, trend_unit)],
  tests[window == "all", .(outcome, model, joint_p_2018_2023 = joint_p)], by = c("outcome", "model"))
verdict[, verdict := fcase(trend_p < 0.05 & joint_p_2018_2023 < 0.05, "CLEARLY NOT PARALLEL",
                           trend_p < 0.05 | joint_p_2018_2023 < 0.05, "WARNING",
                           default = "no evidence against parallel")]
verdict[, outcome := factor(outcome, levels = sapply(outcomes, `[[`, "key"))]
setorder(verdict, outcome, model)

fwrite(es_tab, file.path(tables_dir, "pretrend_event_study.csv"))
fwrite(tests, file.path(tables_dir, "pretrend_tests.csv"))
fwrite(verdict, file.path(tables_dir, "pretrend_verdict.csv"))

# ---------------------------------------------------------------------------- Figure
plot_d <- es_tab[model == "linear"]
plot_d[, outcome := factor(outcome, levels = sapply(outcomes, `[[`, "key"))]
setorder(plot_d, outcome, season)  # panels in research-question order
plot_d[, panel := factor(sprintf("%s (%s)", label, unit), levels = unique(sprintf("%s (%s)", label, unit)))]
p <- ggplot(plot_d, aes(season, estimate)) +
  geom_hline(yintercept = 0, colour = ink_2, linewidth = 0.4) +
  annotate("rect", xmin = 2019.6, xmax = 2020.4, ymin = -Inf, ymax = Inf, fill = grid_col, alpha = 0.6) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0, colour = league_colors[["NFL"]], linewidth = 0.6) +
  geom_line(colour = league_colors[["NFL"]], linewidth = 0.6, alpha = 0.5) +
  geom_point(colour = league_colors[["NFL"]], size = 2.2) +
  facet_wrap(~panel, scales = "free_y", ncol = 3) +
  scale_x_continuous(breaks = 2018:2024) +
  labs(title = "Pre-2025 trends: NFL minus college, relative to 2024 (95% CI)",
       subtitle = "Flat at zero = the leagues moved together before the rule change. Shaded = 2020 (COVID season).",
       x = NULL, y = "Difference vs 2024",
       caption = "Linear models with season fixed effects; SEs clustered by game. 4th-down panels: yardline 30-55, <=5 yds to go.") +
  theme_kball() +
  theme(plot.subtitle = element_text(colour = ink_2, size = 9), axis.text.x = element_text(size = 7.5),
        strip.text = element_text(size = 9.5), panel.spacing = unit(1.2, "lines"))
save_fig(p, file.path(figs_dir, "fig6_pretrend_event_study.png"), width = 11, height = 6.4)

# ---------------------------------------------------------------------------- Report
fmt <- function(x, d = 3) formatC(x, digits = d, format = "f")
v_out <- verdict[, .(outcome = label, model,
                     `diff. trend 2021-24` = sprintf("%s %s (SE %s)", fmt(trend_per_yr, 2), trend_unit, fmt(trend_se, 2)),
                     `trend p` = fmt(trend_p), `joint p (2018-23 = 0)` = fmt(joint_p_2018_2023), verdict)]
t_out <- tests[, .(outcome = label, model, years, n, `joint p` = fmt(joint_p),
                   `diff. trend` = sprintf("%s %s", fmt(trend_per_yr, 2), trend_unit), `trend p` = fmt(trend_p))]
es_out <- dcast(es_tab[model == "linear" & season != ref_year],
                label + unit ~ season, value.var = "estimate", fun.aggregate = function(x) round(x, 2))
report <- c(
  "# Parallel-trends check", "",
  "Generated by `src/04_pretrends.R` using pre-period data only (2018-2024). No 2025 data enters these models.", "",
  "**Decision rule (fixed before running):** an outcome is *clearly not parallel* if the differential linear",
  "trend in 2021-2024 is significant (p < 0.05) **and** the joint test that all 2018-2023 event-study",
  "coefficients are zero rejects (p < 0.05). One test rejecting = *warning*. Not rejecting is not proof of",
  "parallel trends (few pre seasons, limited power).", "",
  "## Verdict by outcome", "", kable(v_out, format = "pipe"), "",
  "## Event-study coefficients (linear models; NFL minus college, relative to 2024)", "",
  kable(es_out, format = "pipe"), "",
  "## All tests (windows: 2018-2024, 2021-2024, 2018-2024 excluding 2020)", "",
  kable(t_out, format = "pipe"), "",
  "Notes: `fg_made` controls for a league-specific quadratic in distance. 4th-down models restrict to",
  "yardline_100 30-55 and ydstogo <= 5 and control (league-specifically) for ydstogo, yardline_100,",
  "score differential and an under-2-minutes flag. All models include season fixed effects;",
  "standard errors clustered by game. Logit trends are on the log-odds scale.", "")
writeLines(report, file.path(root, "outputs", "pretrends_report.md"))
cat(report, sep = "\n")
