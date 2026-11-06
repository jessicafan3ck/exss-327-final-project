# Did the NFL's 2025 K-Ball Rule Change Improve Kicking?

EXSS 327 Final Project, Team 2: Bennett Vitagliano, Freddie Mills, Adam Hesketh, Jessica Fan, Anabeth Tomalis

Difference-in-differences comparison of NFL field-goal accuracy, distance and 4th-down strategy before vs. after
the 2025 K-ball rule change, using college football (FBS) as the control group.

## Status

- [x] Step 1: NFL play-by-play downloaded (2018-2025); brief's sanity-check numbers reproduced exactly
- [x] Step 2: College play-by-play downloaded (2018-2025); data questions resolved (see below)
- [x] Step 3: Cleaned, harmonized tables in `data/clean/` and `outputs/data_quality_report.md`
- [x] Step 4a: Descriptive tables (`outputs/tables/desc_*.csv`) and figures (`outputs/figures/`)
- [x] Step 4b: Parallel-trends check (`outputs/pretrends_report.md`, fig6): no outcome clearly non-parallel; warning on 50+ share
- [ ] Step 5: Models (accuracy, distance, strategy, within-kicker) + robustness
- [ ] Step 6: Figures, tables, written summary

## Reproduce

Requires R (developed on 4.5.1) with these packages (versions used):
`data.table` 1.17.8, `arrow` 25.0.1, `ggplot2` 4.0.1, `knitr` 1.50, `R.utils` 2.13.0, `fixest` 0.13.2.

```bash
Rscript -e 'install.packages(c("data.table", "arrow", "ggplot2", "knitr", "R.utils", "fixest"))'
Rscript --vanilla src/01_download_nfl.R 2018 2025   # ~150 MB, nflverse GitHub releases
Rscript --vanilla src/01_download_cfb.R 2018 2025   # ~740 MB, sportsdataverse GitHub releases
Rscript --vanilla src/02_clean.R                    # data/clean/*.csv + outputs/data_quality_report.md
Rscript --vanilla src/03_descriptives.R             # outputs/tables/desc_*.csv + outputs/figures/
Rscript --vanilla src/04_pretrends.R                # parallel-trends check (pre-period data only)
```

Run from anywhere; scripts locate the project folder themselves.

No CollegeFootballData API key is needed: the college data comes from the pre-built cfbfastR files
(the same ones `cfbfastR::load_cfb_pbp()` reads). Raw files go in `data/raw/` and are not committed.

## Layout

```
data/raw/      downloaded play-by-play (gitignored)
data/clean/    fg_attempts.csv, fourth_down_decisions.csv
src/           01_download_*.R, 02_clean.R, 03_descriptives.R, 04_pretrends.R, plot_style.R
outputs/       data_quality_report.md, figures/, tables/
```

## Clean tables

Both tables cover 2018-2025 regular seasons (main window 2021-2025; 2018-2020 kept for sensitivity checks).
Columns: `league` (NFL/NCAA), `season`, `week`, `game_id`, `play_id`, `team`, `kicker_id`, `kicker_name`,
`kick_distance`, `made`, `blocked`, `down`, `ydstogo`, `yardline_100`, `score_diff`, `wp`,
`game_seconds_remaining`, `decision` (kick/go/punt), `play_type_raw`, `dome`, `temp`, `wind`, `post` (season 2025),
`nfl`, `covid_season` (2020). `fg_attempts.csv` also has `dist_source` (college only).

Read `game_id` as a string (`fread(..., colClasses = list(character = "game_id"))`): NFL ids are text, college ids are numeric.

## Cleaning decisions

Brief rules (section 7) applied as written. Additional decisions:

- **College scope**: regular season, games where *both* teams are FBS (the feed adds FCS games from 2022).
- **College FG distance** is parsed from the play text, falling back to `yards_to_goal + 17`. From 2025 week 9 the
  feed switched text format and its `yards_to_goal` runs ~1 yd short of the stated FG distance; before that the two
  agree exactly. Consequence: college `yardline_100` in late 2025 may be off by ~1 yd (affects the 4th-down model).
- **Impossible distances** (<18 or >75 yds; feed typos) dropped: 12 college attempts over 8 seasons.
- **College duplicates**: the feed's `id_play` is stored as a float and loses precision, so it cannot be used as a key.
  Exact duplicate rows (same game, play number, type, text, down, spot) are dropped (4,829 rows, mostly 2021);
  `play_id` is rebuilt as `game_id_playnumber_seq`.
- **Blocked FGs** count as misses (`blocked` column kept for the sensitivity check).
- **"Go for it"** = run/pass on 4th down (including sacks, interceptions, fumbles, fake punts/FGs), excluding kneels
  and spikes. College fumble rows whose text mentions a punt are classed as punts. Ambiguous college types
  (Penalty, Safety, Uncategorized) are excluded.
- **Dome** (NFL) = fixed dome or closed retractable roof. College has no roof/weather fields in this data.
- **College kicker ids** cover only 31-60% of attempts, so kicker-level analysis is NFL-only.

## Data sources

- nflverse play-by-play: https://github.com/nflverse/nflverse-data/releases/tag/pbp
- cfbfastR / sportsdataverse play-by-play: https://github.com/sportsdataverse/sportsdataverse-data/releases/tag/cfbfastR_cfb_pbp
- NCAA 2025 rule changes (no ball/FG rule change; confirms the control group):
  https://ncaaorg.s3.amazonaws.com/committees/ncaa/prop/Apr2025PROP_April16Report.pdf
