# Descriptive tables and figures by league and season (brief section 8.1).
# Reads data/clean/*.csv; writes outputs/tables/desc_*.csv and outputs/figures/fig*_*.png.
# Usage: Rscript --vanilla src/03_descriptives.R

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
source(file.path(script_dir, "plot_style.R"))
clean_dir <- file.path(root, "data", "clean")
tables_dir <- file.path(root, "outputs", "tables")
figs_dir <- file.path(root, "outputs", "figures")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figs_dir, recursive = TRUE, showWarnings = FALSE)

bin_labels <- c("<30", "30-39", "40-49", "50-59", "60+")
pre_seasons <- 2021:2024

fg <- fread(file.path(clean_dir, "fg_attempts.csv"), colClasses = list(character = c("game_id", "kicker_id")))
fd <- fread(file.path(clean_dir, "fourth_down_decisions.csv"), colClasses = list(character = "game_id"))
fg <- fg[season <= 2025]  # partial 2026 season is handled separately (exploratory)
fd <- fd[season <= 2025]
fg[, dist_bin := cut(kick_distance, c(0, 30, 40, 50, 60, 100), right = FALSE, labels = bin_labels)]
fg[, period := fcase(season %in% pre_seasons, "pre 2021-24", season == 2025, "post 2025", default = "other")]

# ---------------------------------------------------------------------------- Season table
season_tab <- fg[, .(attempts = .N, fg_pct = mean(made) * 100,
                     fg_pct_excl_blocked = mean(made[blocked == 0]) * 100,
                     mean_dist = mean(kick_distance), median_dist = as.double(median(kick_distance))),
                 by = .(league, season)]
dist_ranges <- list(`40_49` = c(40, 49), `50_59` = c(50, 59), `60plus` = c(60, 99), `50plus` = c(50, 99))
for (nm in names(dist_ranges)) {
  r <- dist_ranges[[nm]]
  b <- fg[, .(share = mean(kick_distance >= r[1] & kick_distance <= r[2]) * 100,
              att = sum(kick_distance >= r[1] & kick_distance <= r[2]),
              made_n = sum(kick_distance >= r[1] & kick_distance <= r[2] & made == 1)), by = .(league, season)]
  b[, pct := made_n / att * 100]
  setnames(b, c("share", "att", "made_n", "pct"), paste0(c("share_", "att_", "made_", "fg_pct_"), nm))
  season_tab <- merge(season_tab, b, by = c("league", "season"))
}
d4 <- dcast(fd[, .N, by = .(league, season, decision)][, pct := N / sum(N) * 100, by = .(league, season)],
            league + season ~ decision, value.var = "pct", fill = 0)
setnames(d4, c("go", "kick", "punt"), c("4th_pct_go", "4th_pct_kick", "4th_pct_punt"))
season_tab <- merge(season_tab, d4, by = c("league", "season"))
setorder(season_tab, league, season)
# Round only the saved copy; figure labels use unrounded values (avoids double rounding).
num_cols <- names(season_tab)[sapply(season_tab, is.double)]
fwrite(copy(season_tab)[, (num_cols) := lapply(.SD, round, 2), .SDcols = num_cols],
       file.path(tables_dir, "desc_by_league_season.csv"))

# ---------------------------------------------------------------------------- Distance-bin table
bin_tab <- fg[period != "other", .(attempts = .N, made = sum(made)), by = .(league, dist_bin, period)]
z <- 1.96
bin_tab[, p := made / attempts]
bin_tab[, centre := (p + z^2 / (2 * attempts)) / (1 + z^2 / attempts)]  # Wilson 95% interval
bin_tab[, half := z * sqrt(p * (1 - p) / attempts + z^2 / (4 * attempts^2)) / (1 + z^2 / attempts)]
bin_tab[, `:=`(fg_pct = round(p * 100, 1), ci_lo = round((centre - half) * 100, 1),
               ci_hi = round((centre + half) * 100, 1))]
bin_tab[, c("p", "centre", "half") := NULL]
bin_tab[, period := factor(period, levels = c("pre 2021-24", "post 2025"))]
setorder(bin_tab, league, dist_bin, period)
fwrite(bin_tab, file.path(tables_dir, "desc_make_rate_by_bin_pre_post.csv"))

# ---------------------------------------------------------------------------- Figures
line_by_season <- function(col, ylab, title, file, caption = NULL) {
  d <- season_tab[, .(league, season, y = get(col))]
  last <- d[season == max(season)]
  p <- ggplot(d, aes(season, y, colour = league)) +
    mark_2025() +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    geom_text(data = last, aes(label = sprintf("%s  %.1f", league_labels[league], y)),
              hjust = 0, nudge_x = 0.15, size = 3.1, colour = ink) +
    scale_colour_manual(values = league_colors, labels = league_labels, breaks = names(league_colors)) +
    scale_x_continuous(breaks = sort(unique(d$season)), expand = expansion(add = c(0.3, 1.4))) +
    labs(title = title, x = NULL, y = ylab, caption = caption) +
    theme_kball()
  save_fig(p, file.path(figs_dir, file))
}

line_by_season("fg_pct", "FG made (%)", "Field-goal accuracy by season", "fig1_fg_pct_by_season.png",
               "Raw make rate; not adjusted for distance. Regular season; college = FBS vs FBS.")
line_by_season("share_50plus", "Share of FG attempts from 50+ yds (%)", "Long attempts by season",
               "fig3_share_50plus_by_season.png")
line_by_season("mean_dist", "Mean attempt distance (yds)", "Average FG attempt distance by season",
               "fig4_mean_distance_by_season.png")
line_by_season("4th_pct_go", "Went for it on 4th down (%)", "4th-down go-for-it rate by season",
               "fig5_go_rate_by_season.png", "All 4th downs (pass/run/punt/FG); kneels and spikes excluded.")

# Make rate by distance bin, pre vs post, one panel per league; n per bar in the tick labels.
n_lab <- dcast(bin_tab, league + dist_bin ~ period, value.var = "attempts", fill = 0)
n_lab[, tick := sprintf("%s\n%d / %d", dist_bin, `pre 2021-24`, `post 2025`)]
bars <- merge(bin_tab, n_lab[, .(league, dist_bin, tick)], by = c("league", "dist_bin"))
bars[, league_lab := factor(league_labels[league], levels = league_labels)]
bars[, fill_key := paste(league, period)]
fills <- c(`NFL pre 2021-24` = "#a0c0eb", `NFL post 2025` = league_colors[["NFL"]],
           `NCAA pre 2021-24` = "#f6b8a0", `NCAA post 2025` = league_colors[["NCAA"]])
p2 <- ggplot(bars, aes(tick, fg_pct, group = period)) +
  geom_col(aes(fill = fill_key), position = position_dodge(width = 0.82), width = 0.78) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), position = position_dodge(width = 0.82),
                width = 0.15, colour = ink_2, linewidth = 0.4) +
  facet_wrap(~league_lab, scales = "free_x") +
  scale_fill_manual(values = fills, breaks = names(fills),
                    labels = c("NFL 2021-24", "NFL 2025", "College 2021-24", "College 2025")) +
  scale_y_continuous(limits = c(0, 101), expand = expansion(mult = c(0, 0.02))) +
  labs(title = "Make rate by distance: 2021-24 vs 2025 (bars = 95% CI)",
       x = "Attempt distance (yards); n = attempts pre / post", y = "FG made (%)") +
  guides(fill = guide_legend(nrow = 1)) +
  theme_kball() +
  theme(axis.text.x = element_text(size = 8))
save_fig(p2, file.path(figs_dir, "fig2_make_rate_by_bin_pre_post.png"), width = 11, height = 4.8)

print(season_tab[, .(league, season, attempts, fg_pct, mean_dist, share_50plus, att_60plus, made_60plus, `4th_pct_go`)])
