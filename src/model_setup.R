# Shared data preparation and DiD helpers for 05_models.R and 07_inference.R.
# Expects `root` to be defined by the calling script.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(marginaleffects)
  library(lme4)
  library(nnet)
  library(knitr)
})

clean_dir <- file.path(root, "data", "clean")

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
