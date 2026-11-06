# Clean NFL (nflverse) and college (cfbfastR) play-by-play into two harmonized tables.
#
# Outputs (data/clean/):
#   fg_attempts.csv            one row per FG attempt, both leagues, 2018-2026
#   fourth_down_decisions.csv  one row per 4th-down pass/run/punt/FG decision, both leagues, 2018-2026
# and outputs/data_quality_report.md.
#
# Rules follow section 7 of the project brief. Decisions not fixed by the brief are marked DECISION.
# Usage: Rscript --vanilla src/02_clean.R

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(knitr)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
raw_dir <- file.path(root, "data", "raw")
clean_dir <- file.path(root, "data", "clean")
out_dir <- file.path(root, "outputs")
seasons <- 2018:2026  # 2026 is a partial season, flagged and used for exploratory checks only
post_season <- 2025   # the single post (treated) season

schema <- c("league", "season", "week", "game_id", "play_id", "team", "kicker_id", "kicker_name",
            "kick_distance", "made", "blocked", "down", "ydstogo", "yardline_100", "score_diff", "wp",
            "game_seconds_remaining", "decision", "play_type_raw", "dome", "temp", "wind",
            "post", "nfl", "covid_season", "partial_season")

# ---------------------------------------------------------------------------- NFL
nfl_cols <- c("play_id", "game_id", "season", "season_type", "week", "posteam", "play_type", "down",
              "ydstogo", "yardline_100", "score_differential", "wp", "game_seconds_remaining",
              "kick_distance", "field_goal_result", "kicker_player_id", "kicker_player_name",
              "qb_kneel", "qb_spike", "roof", "temp", "wind")

load_nfl <- function() {
  d <- rbindlist(lapply(seasons, function(s) {
    x <- fread(file.path(raw_dir, "nfl", sprintf("play_by_play_%d.csv.gz", s)), select = nfl_cols,
               showProgress = FALSE)
    x[season_type == "REG"]
  }))
  d <- d[!is.na(play_type) & play_type != "" & play_type != "no_play"]
  d[, .(
    league = "NFL", season, week, game_id,
    play_id = paste0(game_id, "_", as.integer(play_id)), team = posteam,
    kicker_id = kicker_player_id, kicker_name = kicker_player_name,
    kick_distance, made = as.integer(field_goal_result %in% "made"),
    blocked = as.integer(field_goal_result %in% "blocked"), down, ydstogo, yardline_100,
    score_diff = score_differential, wp, game_seconds_remaining,
    decision = fcase(play_type %in% c("pass", "run"), "go", play_type == "punt", "punt",
                     play_type == "field_goal", "kick", default = NA_character_),
    play_type_raw = play_type,
    # DECISION: dome = fixed dome or retractable roof closed; open retractable counts as outdoor.
    dome = fcase(roof %in% c("dome", "closed"), 1L, roof %in% c("outdoors", "open"), 0L, default = NA_integer_),
    temp, wind,
    is_fg = play_type == "field_goal",
    kneel_spike = (qb_kneel %in% 1) | (qb_spike %in% 1)
  )]
}

# ---------------------------------------------------------------------------- College
cfb_cols <- c("game_play_number", "game_id", "season", "season_type", "week", "pos_team", "play_type",
              "play_text", "down", "distance", "yards_to_goal", "pos_score_diff_start", "wp_before", "period",
              "clock_minutes", "clock_seconds", "fg_inds", "fg_made", "field_goal_attempt_player_id",
              "field_goal_attempt_player", "penalty_no_play", "home_team_division", "away_team_division")

cfb_go <- c("Rush", "Rushing Touchdown", "Pass Reception", "Pass Incompletion", "Pass Completion",
            "Passing Touchdown", "Sack", "Interception Return", "Interception Return Touchdown",
            "Fumble", "Fumble Recovery (Own)", "Fumble Recovery (Opponent)", "Fumble Return Touchdown",
            "Fumble Recovery (Opponent) Touchdown")
# Fake punts/FGs are run or pass plays and count as "go", matching nflverse play_type.
cfb_punt <- c("Punt", "Punt Return", "Punt Return Touchdown", "Blocked Punt", "Blocked Punt Touchdown",
              "Punt Team Fumble Recovery", "Blocked Punt (Safety)", "Punt (Safety)")
# DECISION: "Safety", "Penalty", "Uncategorized" etc. are ambiguous about the decision and are left out.

fg_dist_pat <- "(?i)(?:(\\d+)\\s*(?:yd|yard)s?\\s*(?:FG|field goal))|(?:field goal attempt from (\\d+) yard)"

load_cfb <- function() {
  d <- rbindlist(lapply(seasons, function(s) {
    x <- as.data.table(read_parquet(file.path(raw_dir, "cfb", sprintf("play_by_play_%d.parquet", s)),
                                    col_select = all_of(cfb_cols)))
    # Scope: regular season, both teams FBS.
    x[season_type == "regular" & home_team_division == "fbs" & away_team_division == "fbs"]
  }))
  d <- d[!is.na(play_type) & !(penalty_no_play %in% 1)]
  # The feed's id_play is stored as a float and loses precision (distinct plays collide), and
  # game_play_number is not unique within a game either. DECISION: drop rows that are exact copies
  # on game/play number/type/text/down/spot (feed duplicates), then build our own play id.
  n_before <- nrow(d)
  d <- unique(d, by = c("game_id", "game_play_number", "play_type", "play_text", "down", "yards_to_goal"))
  exact_dups <- n_before - nrow(d)
  d[, seq := rowid(game_id, game_play_number) - 1L]

  d[, is_fg := fg_inds %in% 1]
  # Kick distance: parse the official distance from play text; yards_to_goal + 17 as fallback.
  # (From 2025 week 9 the feed's yards_to_goal runs ~1 yd short of the stated FG distance.)
  m <- regmatches(d$play_text, regexec(fg_dist_pat, d$play_text, perl = TRUE))
  txt <- vapply(m, function(g) {
    if (length(g) == 0) return(NA_real_)
    v <- g[2:3][g[2:3] != ""]
    if (length(v)) as.numeric(v[1]) else NA_real_
  }, numeric(1))
  d[, txt_dist := txt]
  d[, text_lc := tolower(fifelse(is.na(play_text), "", play_text))]
  d[, decision := fcase(
    is_fg, "kick",
    play_type %in% cfb_punt, "punt",
    startsWith(play_type, "Fumble") & grepl("punt", text_lc, fixed = TRUE), "punt",  # muffed/fumbled punts
    play_type %in% cfb_go, "go",
    default = NA_character_)]
  d[, secs := (4 - pmin(period, 4)) * 900 + clock_minutes * 60 + clock_seconds]

  out <- d[, .(
    league = "NCAA", season, week, game_id = as.character(game_id),
    play_id = paste0(game_id, "_", as.integer(game_play_number), "_", seq), team = pos_team,
    kicker_id = field_goal_attempt_player_id, kicker_name = field_goal_attempt_player,
    kick_distance = fifelse(is_fg, fifelse(!is.na(txt_dist), txt_dist, yards_to_goal + 17), NA_real_),
    made = fifelse(is_fg, as.integer(fcoalesce(as.numeric(fg_made), 0)), 0L),
    blocked = as.integer(is_fg & grepl("Blocked", play_type, fixed = TRUE)),
    down, ydstogo = distance, yardline_100 = yards_to_goal,
    score_diff = pos_score_diff_start, wp = wp_before,
    game_seconds_remaining = pmax(fifelse(period <= 4, secs, 0), 0),
    decision, play_type_raw = play_type,
    dome = NA_integer_, temp = NA_real_, wind = NA_real_,  # not in cfbfastR pbp
    is_fg, kneel_spike = grepl("\\bkneel|\\bspike", text_lc, perl = TRUE),
    dist_source = fifelse(is_fg, fifelse(!is.na(txt_dist), "text", "yards_to_goal+17"), NA_character_)
  )]
  attr(out, "exact_dups_dropped") <- exact_dups
  out
}

# ---------------------------------------------------------------------------- Build
finalize <- function(d) {
  d[, `:=`(post = as.integer(season == post_season), nfl = as.integer(league == "NFL"),
           covid_season = as.integer(season == 2020), partial_season = as.integer(season == 2026))]
  d
}

md_table <- function(x) c(knitr::kable(x, format = "pipe", digits = 3), "")

nfl <- load_nfl()
cfb <- load_cfb()
exact_dups <- attr(cfb, "exact_dups_dropped")
stopifnot(!anyDuplicated(nfl$play_id), !anyDuplicated(cfb$play_id))

report <- c("# Data-quality report", "",
            "Generated by `src/02_clean.R`. Regular season only; college = FBS-vs-FBS games.", "",
            sprintf("- NFL: %s regular-season plays after dropping no-plays; duplicate play ids: 0",
                    format(nrow(nfl), big.mark = ",")),
            sprintf("- NCAA: %s regular-season plays after dropping no-plays; duplicate play ids: 0",
                    format(nrow(cfb), big.mark = ",")),
            sprintf("- NCAA exact duplicate rows dropped (feed duplicates): %s", format(exact_dups, big.mark = ",")))

# FG attempts: drop rows missing down or distance (rule 2); XPs/2pt are separate play types.
# DECISION: also drop impossible distances (<18 or >75 yds; feed typos, a few per season).
fg_drops <- list()
fg <- rbindlist(lapply(list(nfl, cfb), function(d) {
  x <- d[is_fg == TRUE]
  missing <- is.na(x$down) | is.na(x$kick_distance)
  impossible <- !missing & !(x$kick_distance >= 18 & x$kick_distance <= 75)
  fg_drops[[x$league[1]]] <<- c(sum(missing), sum(impossible))
  x[!missing & !impossible]
}), fill = TRUE)
fg <- finalize(fg)

# 4th-down decisions: pass/run/punt/FG on 4th down, excluding kneels and spikes (rule 6).
fd <- rbindlist(list(nfl, cfb), fill = TRUE)
fd <- finalize(fd[down %in% 4 & !is.na(decision) & !kneel_spike])

fg_out <- fg[, c(schema, "dist_source"), with = FALSE]
setorder(fg_out, league, season, week, game_id)
fd_out <- fd[, setdiff(schema, c("made", "blocked", "kick_distance", "kicker_id", "kicker_name")), with = FALSE]
setorder(fd_out, league, season, week, game_id)
dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(fg_out, file.path(clean_dir, "fg_attempts.csv"))
fwrite(fd_out, file.path(clean_dir, "fourth_down_decisions.csv"))

# ---------------------------------------------------------------------------- Report
report <- c(report, "", "## Dropped rows", "",
            sprintf("- %s FG attempts dropped: %d missing down/distance, %d impossible distance",
                    names(fg_drops), sapply(fg_drops, `[`, 1), sapply(fg_drops, `[`, 2)))

t <- fg_out[, .(games = uniqueN(game_id), attempts = .N, fg_pct = round(mean(made) * 100, 1),
                avg_dist = round(mean(kick_distance), 1), att_50plus = sum(kick_distance >= 50),
                att_60plus = sum(kick_distance >= 60), blocked = sum(blocked),
                kicker_id_coverage = round(mean(!is.na(kicker_id) & kicker_id != ""), 2)),
            by = .(league, season)]
report <- c(report, "", "## FG attempts by league and season", "", md_table(t))

t4 <- dcast(fd_out[, .N, by = .(league, season, decision)], league + season ~ decision, value.var = "N", fill = 0)
t4[, total := go + kick + punt][, go_pct := round(go / total * 100, 1)]
report <- c(report, "## 4th-down decisions by league and season", "", md_table(t4))

share_na <- function(d, cols) {
  m <- d[, lapply(.SD, function(v) round(mean(is.na(v) | (is.character(v) & v == "")), 3)), by = league, .SDcols = cols]
  m <- transpose(m, keep.names = "column", make.names = "league")
  setcolorder(m, c("column", sort(setdiff(names(m), "column"))))
  m
}
key <- c("kick_distance", "down", "ydstogo", "yardline_100", "score_diff", "wp",
         "game_seconds_remaining", "kicker_id", "dome", "temp", "wind")
key4 <- c("down", "ydstogo", "yardline_100", "score_diff", "wp", "game_seconds_remaining")
report <- c(report, "## Missing values in key columns (share of rows)", "",
            "FG attempts:", "", md_table(share_na(fg_out, key)),
            "4th-down decisions:", "", md_table(share_na(fd_out, key4)),
            paste("Note: NFL `temp`/`wind` are missing by design for dome/closed-roof games.",
                  "College has no roof/weather fields in the cfbfastR play-by-play."), "")

src <- dcast(fg_out[league == "NCAA", .N, by = .(season, dist_source)], season ~ dist_source,
             value.var = "N", fill = 0)
rng <- fg_out[, .(min = min(kick_distance), max = max(kick_distance)), by = league]
report <- c(report, "## College distance source", "", md_table(src), "Distance range:", "", md_table(rng))

# Sanity checks vs brief section 6.1
expected <- list(`2024` = c(1115, 84.0, 40.1, 279, 3826, 20.0), `2025` = c(1088, 85.6, 40.5, 266, 3793, 23.3))
metric_names <- c("FG attempts", "FG %", "Avg distance", "50+ attempts", "4th-down plays", "Go-for-it %")
rows <- c("| Season | Metric | Expected | Got | OK |", "|---|---|---|---|---|")
for (s in names(expected)) {
  f <- fg_out[league == "NFL" & season == as.integer(s)]
  q <- fd_out[league == "NFL" & season == as.integer(s)]
  got <- c(nrow(f), round(mean(f$made) * 100, 1), round(mean(f$kick_distance), 1),
           sum(f$kick_distance >= 50), nrow(q), round(mean(q$decision == "go") * 100, 1))
  ok <- ifelse(abs(expected[[s]] - got) < 0.051, "yes", "NO")
  rows <- c(rows, sprintf("| %s | %s | %s | %s | %s |", s, metric_names, expected[[s]], got, ok))
}
report <- c(report, "## Sanity checks against the project brief (NFL)", "", rows, "")

writeLines(report, file.path(out_dir, "data_quality_report.md"))
cat(report, sep = "\n")
