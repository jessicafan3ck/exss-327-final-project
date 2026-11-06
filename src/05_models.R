# Models (brief sections 8.2-8.6): DiD for accuracy, distance and 4th-down strategy; effect by
# distance bin; each league's own pre/post; within-kicker NFL check; robustness, placebo, exploratory 2026.
#
# Main sample: 2021-2024 (pre) vs 2025 (post), NFL (treated) vs college FBS (control).
# Effects are reported as average effects on the treated (NFL 2025 plays), in percentage points
# (binary outcomes) or yards, with 95% CIs; SEs clustered by game.
#
# Planned tests (brief section 3), Holm-adjusted together:
#   H2 accuracy, H2 attempt distance, H2 share 50+, H3 kick on 4th, H3 go on 4th.
# H1 (NFL-only change) and H4 (by distance bin: 50-59, 60+) are planned but reported separately.
# Everything else (robustness, placebo, 2026) is exploratory.
#
# Outputs: outputs/tables/model_*.csv, outputs/models_report.md
# Usage: Rscript --vanilla src/05_models.R

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(marginaleffects)
  library(lme4)
  library(nnet)
  library(knitr)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
clean_dir <- file.path(root, "data", "clean")
tables_dir <- file.path(root, "outputs", "tables")
set.seed(327)

fg_all <- fread(file.path(clean_dir, "fg_attempts.csv"), colClasses = list(character = c("game_id", "kicker_id")))
fd_all <- fread(file.path(clean_dir, "fourth_down_decisions.csv"), colClasses = list(character = "game_id"))

bin_labels <- c("<40", "40-49", "50-59", "60+")
fg_all[, `:=`(long50 = as.integer(kick_distance >= 50), season_c = season - 2024,
              dbin = cut(kick_distance, c(0, 40, 50, 60, 100), right = FALSE, labels = bin_labels))]
# NFL weather controls (robustness only). Domes/closed roofs have no temp/wind by design: set to
# neutral values and let the dome flag absorb them. Outdoor rows missing weather get the outdoor median.
nfl_out <- fg_all[nfl == 1 & dome == 0]
med_temp <- median(nfl_out$temp, na.rm = TRUE); med_wind <- median(nfl_out$wind, na.rm = TRUE)
n_weather_imputed <- nfl_out[, sum(is.na(temp) | is.na(wind))]
fg_all[, `:=`(
  nfl_dome = fifelse(nfl == 1, fcoalesce(as.numeric(dome), 0), 0),
  nfl_temp = fifelse(nfl == 1 & dome %in% 0, fcoalesce(as.numeric(temp), med_temp), 0),
  nfl_wind = fifelse(nfl == 1 & dome %in% 0, fcoalesce(as.numeric(wind), med_wind), 0))]

fd_all[, `:=`(kick = as.integer(decision == "kick"), go = as.integer(decision == "go"),
              late = as.integer(game_seconds_remaining < 120), season_c = season - 2024)]
in_universe <- function(d) d[yardline_100 >= 30 & yardline_100 <= 55 & ydstogo <= 5]

dist_ctrl <- "nfl * (kick_distance + I(kick_distance^2))"
fd_ctrl <- "nfl * (ydstogo + yardline_100 + score_diff + late)"

# ---------------------------------------------------------------------------- Helpers
# Fit a DiD model and return the average effect of treat on treated rows.
did <- function(y, data, ctrl, family = c("logit", "linear"), extra = "", label = "", spec = "") {
  family <- match.arg(family)
  data <- as.data.frame(data)
  fml <- as.formula(sprintf("%s ~ treat + factor(season) + %s%s", y, ctrl, extra))
  m <- if (family == "logit") feglm(fml, data, family = binomial(), cluster = ~game_id)
       else feols(fml, data, cluster = ~game_id)
  nd <- data[data$treat == 1, ]
  ac <- avg_comparisons(m, variables = "treat", newdata = nd)
  scale <- if (y %in% c("made", "long50", "kick", "go")) 100 else 1
  data.table(outcome = label, spec = spec, model = family, n = nobs(m), n_treated = nrow(nd),
             estimate = ac$estimate * scale, se = ac$std.error * scale,
             ci_lo = ac$conf.low * scale, ci_hi = ac$conf.high * scale, p = ac$p.value,
             unit = if (scale == 100) "pp" else "yds",
             coef = coef(m)[["treat"]], coef_se = se(m)[["treat"]])
}

sample_fg <- function(pre, post_yrs = 2025, drop_blocked = FALSE) {
  d <- fg_all[season %in% c(pre, post_yrs)]
  if (drop_blocked) d <- d[blocked == 0]
  d[, treat := as.integer(nfl == 1 & season %in% post_yrs)]
  d
}
sample_fd <- function(pre, post_yrs = 2025, universe = in_universe) {
  d <- universe(fd_all[season %in% c(pre, post_yrs)])
  d[, treat := as.integer(nfl == 1 & season %in% post_yrs)]
  d
}

outcome_specs <- list(
  list(key = "accuracy", label = "FG made (distance-adjusted)", y = "made", src = "fg", ctrl = dist_ctrl),
  list(key = "distance", label = "Attempt distance", y = "kick_distance", src = "fg", ctrl = "nfl"),
  list(key = "long50", label = "Share of attempts 50+ yds", y = "long50", src = "fg", ctrl = "nfl"),
  list(key = "kick4", label = "Kick on 4th down (FG range, <=5 to go)", y = "kick", src = "fd", ctrl = fd_ctrl),
  list(key = "go4", label = "Go for it on 4th down (FG range, <=5 to go)", y = "go", src = "fd", ctrl = fd_ctrl)
)
fam_of <- function(o) if (o$y == "kick_distance") "linear" else "logit"
get_sample <- function(o, pre, post_yrs = 2025, ...) if (o$src == "fg") sample_fg(pre, post_yrs, ...) else sample_fd(pre, post_yrs, ...)

# ---------------------------------------------------------------------------- Main DiD (H2, H3)
pre_main <- 2021:2024
main <- rbindlist(lapply(outcome_specs, function(o)
  did(o$y, get_sample(o, pre_main), o$ctrl, fam_of(o), label = o$label, spec = "main")))
main[, `:=`(hypothesis = c("H2", "H2", "H2", "H3", "H3"), p_holm = p.adjust(p, method = "holm"))]
fwrite(main, file.path(tables_dir, "model_main_did.csv"))

# ---------------------------------------------------------------------------- By distance bin (H4)
d_bin <- as.data.frame(sample_fg(pre_main))
m_bin <- feglm(as.formula(sprintf("made ~ treat:dbin + factor(season) + %s", dist_ctrl)), d_bin,
               family = binomial(), cluster = ~game_id)
ac_bin <- avg_comparisons(m_bin, variables = "treat", newdata = d_bin[d_bin$treat == 1, ], by = "dbin")
n_cells <- as.data.table(d_bin)[, .(n = .N), by = .(dbin, league, post = season == 2025)]
n_cells <- dcast(n_cells, dbin ~ league + post, value.var = "n", fill = 0)
by_bin <- data.table(dbin = as.character(ac_bin$dbin), estimate = ac_bin$estimate * 100,
                     se = ac_bin$std.error * 100, ci_lo = ac_bin$conf.low * 100, ci_hi = ac_bin$conf.high * 100,
                     p = ac_bin$p.value)
by_bin <- merge(by_bin, n_cells[, .(dbin = as.character(dbin), nfl_pre = NFL_FALSE, nfl_2025 = NFL_TRUE,
                                    college_pre = NCAA_FALSE, college_2025 = NCAA_TRUE)], by = "dbin")
by_bin[, `:=`(dbin = factor(dbin, levels = bin_labels),
              status = fifelse(dbin %in% c("50-59", "60+"), "planned (H4)", "context"))]
setorder(by_bin, dbin)
fwrite(by_bin, file.path(tables_dir, "model_did_by_bin.csv"))

# ---------------------------------------------------------------------------- Single-league pre/post (H1)
# H1 is the NFL row; the college row shows the control group's own change for comparison.
league_pp <- function(lg, y, ctrl, family, label) {
  d <- as.data.frame(fg_all[league == lg & season %in% 2021:2025])
  fml <- as.formula(sprintf("%s ~ post%s", y, ctrl))
  m <- if (family == "logit") feglm(fml, d, family = binomial(), cluster = ~game_id)
       else feols(fml, d, cluster = ~game_id)
  ac <- avg_comparisons(m, variables = "post", newdata = d[d$post == 1, ])
  sc <- if (family == "logit") 100 else 1
  data.table(league = lg, outcome = label, estimate = ac$estimate * sc, ci_lo = ac$conf.low * sc,
             ci_hi = ac$conf.high * sc, p = ac$p.value, unit = if (sc == 100) "pp" else "yds")
}
h1 <- rbindlist(lapply(c("NFL", "NCAA"), function(lg) rbind(
  league_pp(lg, "made", " + kick_distance + I(kick_distance^2)", "logit", "FG made (distance-adjusted)"),
  league_pp(lg, "made", "", "logit", "FG made (raw)"),
  league_pp(lg, "kick_distance", "", "linear", "Attempt distance"),
  league_pp(lg, "long50", "", "logit", "Share of attempts 50+ yds"))))
fwrite(h1, file.path(tables_dir, "model_league_prepost.csv"))

# ---------------------------------------------------------------------------- Multinomial strategy
d_mn <- as.data.frame(sample_fd(pre_main))
d_mn$decision <- relevel(factor(d_mn$decision), ref = "go")
mn <- multinom(as.formula(sprintf("decision ~ treat + factor(season) + %s", fd_ctrl)), d_mn, trace = FALSE)
mn_s <- summary(mn)
multinom_tab <- data.table(
  contrast = paste(rownames(mn_s$coefficients), "vs go"),
  rrr = exp(mn_s$coefficients[, "treat"]),
  ci_lo = exp(mn_s$coefficients[, "treat"] - 1.96 * mn_s$standard.errors[, "treat"]),
  ci_hi = exp(mn_s$coefficients[, "treat"] + 1.96 * mn_s$standard.errors[, "treat"]),
  p = 2 * pnorm(-abs(mn_s$coefficients[, "treat"] / mn_s$standard.errors[, "treat"])),
  n = nrow(d_mn))
fwrite(multinom_tab, file.path(tables_dir, "model_multinom_strategy.csv"))

# ---------------------------------------------------------------------------- Within-kicker NFL (8.5)
nfl_k <- fg_all[nfl == 1 & season %in% 2021:2025]
nfl_k[, period := fifelse(season == 2025, "post", "pre")]
# Expected make probability from the NFL pre-period distance curve -> FG% over expected (FGOE).
xp_model <- glm(made ~ kick_distance + I(kick_distance^2), binomial(), data = nfl_k[period == "pre"])
nfl_k[, xp := predict(xp_model, newdata = nfl_k, type = "response")]

within_kicker <- function(min_att) {
  counts <- dcast(nfl_k[, .N, by = .(kicker_id, period)], kicker_id ~ period, value.var = "N", fill = 0)
  keep <- counts[pre >= min_att & post >= min_att, kicker_id]
  k <- nfl_k[kicker_id %in% keep]
  per <- k[, .(name = last(kicker_name), att = .N, fg_pct = mean(made) * 100, fgoe = mean(made - xp) * 100,
               mean_dist = mean(kick_distance)), by = .(kicker_id, period)]
  w <- dcast(per, kicker_id ~ period, value.var = c("name", "att", "fg_pct", "fgoe", "mean_dist"))
  w[, name := fcoalesce(name_post, name_pre)][, c("name_pre", "name_post") := NULL]
  tests <- rbindlist(lapply(c("fg_pct", "fgoe", "mean_dist"), function(v) {
    diff <- w[[paste0(v, "_post")]] - w[[paste0(v, "_pre")]]
    tt <- t.test(diff); wx <- suppressWarnings(wilcox.test(diff))
    data.table(min_attempts = min_att, kickers = length(keep), measure = v, mean_change = mean(diff),
               ci_lo = tt$conf.int[1], ci_hi = tt$conf.int[2], t_p = tt$p.value, wilcoxon_p = wx$p.value,
               share_improved = mean(diff > 0))
  }))
  mm <- glmer(made ~ post + scale(kick_distance) + I(scale(kick_distance)^2) + (1 | kicker_id),
              data = k, family = binomial(), control = glmerControl(optimizer = "bobyqa"))
  cm <- summary(mm)$coefficients["post", ]
  tests <- rbind(tests, data.table(min_attempts = min_att, kickers = length(keep),
                                   measure = "mixed-logit post (log-odds)", mean_change = cm[["Estimate"]],
                                   ci_lo = cm[["Estimate"]] - 1.96 * cm[["Std. Error"]],
                                   ci_hi = cm[["Estimate"]] + 1.96 * cm[["Std. Error"]],
                                   t_p = cm[["Pr(>|z|)"]], wilcoxon_p = NA_real_, share_improved = NA_real_))
  list(tests = tests, per_kicker = w)
}
wk <- lapply(c(15, 10, 20), within_kicker)
wk_tests <- rbindlist(lapply(wk, `[[`, "tests"))
fwrite(wk_tests, file.path(tables_dir, "model_within_kicker.csv"))
fwrite(wk[[1]]$per_kicker, file.path(tables_dir, "model_within_kicker_per_kicker_min15.csv"))

# ---------------------------------------------------------------------------- Robustness (8.6)
rob <- list()
for (o in outcome_specs) {
  fam <- fam_of(o)
  add <- function(d, spec, family = fam, ctrl = o$ctrl, extra = "")
    rob[[length(rob) + 1]] <<- did(o$y, d, ctrl, family, extra, label = o$label, spec = spec)
  add(get_sample(o, pre_main), "Main: 2021-24 vs 2025")
  add(get_sample(o, setdiff(2018:2024, 2020)), "Baseline 2018-24, excl. 2020")
  add(get_sample(o, 2018:2024), "Baseline 2018-24, incl. 2020")
  add(get_sample(o, 2023:2024), "Baseline 2023-24 only (2024 was a weak NFL year)")
  add(get_sample(o, pre_main), "Allow NFL-specific linear pre-trend", extra = " + nfl:season_c")
  if (fam == "logit") add(get_sample(o, pre_main), "Linear probability model", family = "linear")
  if (o$key == "accuracy") {
    add(sample_fg(pre_main, drop_blocked = TRUE), "Exclude blocked kicks")
    add(get_sample(o, pre_main), "Add NFL dome/temp/wind controls", extra = " + nfl_dome + nfl_temp + nfl_wind")
  }
  if (o$src == "fd") {
    wide <- function(d) d[yardline_100 <= 55]
    add(sample_fd(pre_main, universe = wide), "All 4th downs inside opp. 45 (any distance)")
  }
  if (o$src == "fg") {
    # College distance from field position instead of play text. Identical before 2025; from 2025
    # week 9 the two disagree by ~1 yd and we cannot tell which one the feed has right.
    alt <- get_sample(o, pre_main)
    alt[nfl == 0, kick_distance := yardline_100 + 17]
    alt <- alt[kick_distance >= 18 & kick_distance <= 75]
    alt[, long50 := as.integer(kick_distance >= 50)]
    add(alt, "College distance from field position (yards_to_goal + 17)")
  }
  # Placebo: pretend the rule started in 2024, using pre-period data only. Should be ~0.
  pl <- if (o$src == "fg") fg_all[season %in% 2021:2024] else in_universe(fd_all[season %in% 2021:2024])
  pl[, treat := as.integer(nfl == 1 & season == 2024)]
  add(pl, "Placebo: fake rule in 2024 (2021-23 vs 2024)")
  # Exploratory: partial 2026 season as 'post', same weeks in every season for comparability.
  max_wk <- fg_all[season == 2026, max(week), by = league]
  same_weeks <- function(d) d[week <= max_wk[match(d$league, max_wk$league), V1]]
  e26 <- same_weeks(if (o$src == "fg") fg_all[season %in% c(pre_main, 2026)]
                    else in_universe(fd_all[season %in% c(pre_main, 2026)]))
  e26[, treat := as.integer(nfl == 1 & season == 2026)]
  add(e26, "Exploratory: 2026 YTD as post (same weeks each season)")
}
robust <- rbindlist(rob)
robust[, status := fifelse(spec == "Main: 2021-24 vs 2025", "planned", "exploratory")]
fwrite(robust, file.path(tables_dir, "model_robustness.csv"))

# ---------------------------------------------------------------------------- 2026 descriptive
max_wk <- fg_all[season == 2026, .(max_week = max(week)), by = league]
e_desc <- merge(fg_all[season >= 2021], max_wk, by = "league")[week <= max_week]
explore_2026 <- e_desc[, .(weeks = sprintf("1-%d", max_week[1]), attempts = .N, fg_pct = mean(made) * 100,
                           mean_dist = mean(kick_distance), share_50plus = mean(long50) * 100,
                           att_60plus = sum(kick_distance >= 60), made_60plus = sum(kick_distance >= 60 & made == 1)),
                       by = .(league, season)]
setorder(explore_2026, league, season)
fwrite(explore_2026, file.path(tables_dir, "explore_2026_same_weeks.csv"))

# ---------------------------------------------------------------------------- Report
f2 <- function(x) formatC(x, digits = 2, format = "f")
f3 <- function(x) formatC(x, digits = 3, format = "f")
ci <- function(e, l, h) sprintf("%s [%s, %s]", f2(e), f2(l), f2(h))
report <- c(
  "# Model results", "",
  "Generated by `src/05_models.R`. Effects are average effects on NFL 2025 plays relative to the",
  "counterfactual implied by college's change (DiD), in percentage points (pp) or yards, 95% CI.",
  "SEs clustered by game. Main sample: 2021-24 vs 2025, NFL vs college FBS, regular season.", "",
  "## Main difference-in-differences (planned: H2, H3)", "",
  kable(main[, .(hypothesis, outcome, model, `effect [95% CI]` = ci(estimate, ci_lo, ci_hi), unit,
                 p = f3(p), `p (Holm, 5 tests)` = f3(p_holm), n)], format = "pipe"), "",
  "## Accuracy effect by distance bin (planned for 50-59 and 60+: H4)", "",
  kable(by_bin[, .(bin = dbin, status, `effect pp [95% CI]` = ci(estimate, ci_lo, ci_hi), p = f3(p),
                   nfl_pre, nfl_2025, college_pre, college_2025)], format = "pipe"), "",
  "## Each league's own change, 2025 vs 2021-24 (H1 = NFL rows; college shown for comparison)", "",
  kable(h1[, .(league, outcome, `change [95% CI]` = ci(estimate, ci_lo, ci_hi), unit, p = f3(p))], format = "pipe"), "",
  "## Multinomial 4th-down choice (base = go for it; FG range, <=5 to go)", "",
  "Relative risk ratios for the NFL-2025 term. SEs are not clustered (nnet::multinom), so CIs are too narrow.", "",
  kable(multinom_tab[, .(contrast, RRR = f2(rrr), `95% CI` = sprintf("[%s, %s]", f2(ci_lo), f2(ci_hi)), p = f3(p), n)],
        format = "pipe"), "",
  "## Within-kicker NFL check (kickers with >= N attempts in 2021-24 and in 2025)", "",
  "`fgoe` = FG% over expected from the NFL 2021-24 distance curve. No control group: this is the NFL change",
  "holding kicker fixed, and includes only kickers who stayed in the league (survivorship).", "",
  kable(wk_tests[, .(`min att` = min_attempts, kickers, measure, `mean change [95% CI]` = ci(mean_change, ci_lo, ci_hi),
                     `t / z p` = f3(t_p), `Wilcoxon p` = f3(wilcoxon_p), `share improved` = f2(share_improved))],
        format = "pipe"), "",
  "## Robustness, placebo and exploratory 2026", "",
  kable(robust[, .(outcome, spec, model, `effect [95% CI]` = ci(estimate, ci_lo, ci_hi), unit, p = f3(p), n)],
        format = "pipe"), "",
  sprintf("Weather controls: %d NFL outdoor attempts had missing temp/wind and were set to the outdoor median.",
          n_weather_imputed), "",
  "## Exploratory: same weeks of each season (2026 is partial)", "",
  kable(explore_2026[, .(league, season, weeks, attempts, `FG%` = f2(fg_pct), `mean dist` = f2(mean_dist),
                         `50+ share` = f2(share_50plus), `60+ made/att` = sprintf("%d/%d", made_60plus, att_60plus))],
        format = "pipe"), "")
writeLines(report, file.path(root, "outputs", "models_report.md"))
cat(report, sep = "\n")
