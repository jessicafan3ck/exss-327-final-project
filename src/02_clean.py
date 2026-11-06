"""Clean NFL (nflverse) and college (cfbfastR) play-by-play into two harmonized tables.

Outputs (data/clean/):
  fg_attempts.csv            one row per FG attempt, both leagues, 2018-2025
  fourth_down_decisions.csv  one row per 4th-down pass/run/punt/FG decision, both leagues, 2018-2025
and outputs/data_quality_report.md.

Rules follow section 7 of the project brief. Decisions not fixed by the brief are marked DECISION.
Usage: python -I src/02_clean.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
CLEAN = ROOT / "data" / "clean"
OUT = ROOT / "outputs"
SEASONS = range(2018, 2026)
POST_SEASON = 2025

SCHEMA = ["league", "season", "week", "game_id", "play_id", "team", "kicker_id", "kicker_name",
          "kick_distance", "made", "blocked", "down", "ydstogo", "yardline_100", "score_diff", "wp",
          "game_seconds_remaining", "decision", "play_type_raw", "dome", "temp", "wind",
          "post", "nfl", "covid_season"]

# ----------------------------------------------------------------------------- NFL
NFL_COLS = ["play_id", "game_id", "season", "season_type", "week", "posteam", "play_type", "down",
            "ydstogo", "yardline_100", "score_differential", "wp", "game_seconds_remaining",
            "kick_distance", "field_goal_result", "kicker_player_id", "kicker_player_name",
            "qb_kneel", "qb_spike", "roof", "temp", "wind"]


def load_nfl() -> pd.DataFrame:
    frames = []
    for s in SEASONS:
        d = pd.read_csv(RAW / "nfl" / f"play_by_play_{s}.csv.gz", usecols=NFL_COLS, low_memory=False)
        frames.append(d[d.season_type == "REG"])
    d = pd.concat(frames, ignore_index=True)
    d = d[d.play_type.notna() & (d.play_type != "no_play")]
    out = pd.DataFrame({
        "league": "NFL", "season": d.season, "week": d.week, "game_id": d.game_id,
        "play_id": d.game_id + "_" + d.play_id.astype(int).astype(str), "team": d.posteam,
        "kicker_id": d.kicker_player_id, "kicker_name": d.kicker_player_name,
        "kick_distance": d.kick_distance, "made": (d.field_goal_result == "made").astype(int),
        "blocked": (d.field_goal_result == "blocked").astype(int), "down": d.down,
        "ydstogo": d.ydstogo, "yardline_100": d.yardline_100, "score_diff": d.score_differential,
        "wp": d.wp, "game_seconds_remaining": d.game_seconds_remaining,
        "play_type_raw": d.play_type,
        # DECISION: dome = fixed dome or retractable roof closed; open retractable counts as outdoor.
        "dome": d.roof.map({"dome": 1, "closed": 1, "outdoors": 0, "open": 0}),
        "temp": d.temp, "wind": d.wind,
        "is_fg": d.play_type == "field_goal",
        "kneel_spike": (d.qb_kneel == 1) | (d.qb_spike == 1),
    })
    out["decision"] = d.play_type.map({"pass": "go", "run": "go", "punt": "punt", "field_goal": "kick"})
    return out


# ----------------------------------------------------------------------------- College
CFB_COLS = ["game_play_number", "game_id", "season", "season_type", "week", "pos_team", "play_type", "play_text",
            "down", "distance", "yards_to_goal", "pos_score_diff_start", "wp_before", "period",
            "clock_minutes", "clock_seconds", "fg_inds", "fg_made", "field_goal_attempt_player_id",
            "field_goal_attempt_player", "penalty_no_play", "home_team_division", "away_team_division"]

CFB_GO = {"Rush", "Rushing Touchdown", "Pass Reception", "Pass Incompletion", "Pass Completion",
          "Passing Touchdown", "Sack", "Interception Return", "Interception Return Touchdown",
          "Fumble", "Fumble Recovery (Own)", "Fumble Recovery (Opponent)", "Fumble Return Touchdown",
          "Fumble Recovery (Opponent) Touchdown"}
# Fake punts/FGs are run or pass plays and count as "go", matching nflverse play_type.
CFB_PUNT = {"Punt", "Punt Return", "Punt Return Touchdown", "Blocked Punt", "Blocked Punt Touchdown",
            "Punt Team Fumble Recovery", "Blocked Punt (Safety)", "Punt (Safety)"}
# DECISION: "Safety", "Penalty", "Uncategorized" etc. are ambiguous about the decision and are left out.

FG_DIST_PAT = r"(?:(\d+)\s*(?:yd|yard)s?\s*(?:FG|field goal))|(?:field goal attempt from (\d+) yard)"


def load_cfb() -> pd.DataFrame:
    frames = []
    for s in SEASONS:
        d = pd.read_parquet(RAW / "cfb" / f"play_by_play_{s}.parquet", columns=CFB_COLS)
        # Scope: regular season, both teams FBS.
        d = d[(d.season_type == "regular") & (d.home_team_division == "fbs")
              & (d.away_team_division == "fbs")]
        frames.append(d)
    d = pd.concat(frames, ignore_index=True)
    d = d[d.play_type.notna() & (d.penalty_no_play != 1)]
    # The feed's id_play is stored as float64 and loses precision (distinct plays collide), and
    # game_play_number is not unique within a game either. DECISION: drop rows that are exact copies
    # on game/play number/type/text/down/spot (feed duplicates), then build our own play id.
    content = ["game_id", "game_play_number", "play_type", "play_text", "down", "yards_to_goal"]
    n_before = len(d)
    d = d.drop_duplicates(content)
    d.attrs["exact_dups_dropped"] = n_before - len(d)
    seq = d.groupby(["game_id", "game_play_number"]).cumcount()

    is_fg = d.fg_inds == 1
    # Kick distance: parse the official distance from play text; yards_to_goal + 17 as fallback.
    # (From 2025 week 9 the feed's yards_to_goal runs ~1 yd short of the stated FG distance.)
    m = d.play_text.str.extract(FG_DIST_PAT, flags=2)
    txt = pd.to_numeric(m[0].fillna(m[1]), errors="coerce")
    derived = d.yards_to_goal + 17
    dist = txt.where(txt.notna(), derived)
    dist_source = np.where(txt.notna(), "text", "yards_to_goal+17")

    text = d.play_text.fillna("").str.lower()
    decision = pd.Series(np.select(
        [is_fg, d.play_type.isin(CFB_PUNT), d.play_type.str.startswith("Fumble") & text.str.contains("punt"),  # muffed/fumbled punts
         d.play_type.isin(CFB_GO)],
        ["kick", "punt", "punt", "go"], default=None), index=d.index)

    period = d.period.clip(upper=4)
    secs = (4 - period) * 900 + d.clock_minutes * 60 + d.clock_seconds
    out = pd.DataFrame({
        "league": "NCAA", "season": d.season, "week": d.week, "game_id": d.game_id.astype(str),
        "play_id": (d.game_id.astype(str) + "_" + d.game_play_number.astype(int).astype(str)
                    + "_" + seq.astype(str)), "team": d.pos_team,
        "kicker_id": d.field_goal_attempt_player_id, "kicker_name": d.field_goal_attempt_player,
        "kick_distance": dist.where(is_fg), "made": d.fg_made.fillna(0).astype(int).where(is_fg, 0),
        "blocked": (is_fg & d.play_type.str.contains("Blocked")).astype(int),
        "down": d.down, "ydstogo": d.distance, "yardline_100": d.yards_to_goal,
        "score_diff": d.pos_score_diff_start, "wp": d.wp_before,
        "game_seconds_remaining": secs.where(d.period <= 4, 0).clip(lower=0),
        "decision": decision, "play_type_raw": d.play_type,
        "dome": np.nan, "temp": np.nan, "wind": np.nan,  # not in cfbfastR pbp
        "is_fg": is_fg, "kneel_spike": text.str.contains(r"\bkneel|\bspike"),
        "dist_source": np.where(is_fg, dist_source, None),
    })
    out.attrs = d.attrs
    return out


# ----------------------------------------------------------------------------- Build
def finalize(df: pd.DataFrame) -> pd.DataFrame:
    df["post"] = (df.season >= POST_SEASON).astype(int)
    df["nfl"] = (df.league == "NFL").astype(int)
    df["covid_season"] = (df.season == 2020).astype(int)
    return df


def main():
    CLEAN.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    nfl, cfb = load_nfl(), load_cfb()
    report = ["# Data-quality report", "",
              "Generated by `src/02_clean.py`. Regular season only; college = FBS-vs-FBS games.", ""]

    # Duplicates on play key, before filtering further.
    for name, d in [("NFL", nfl), ("NCAA", cfb)]:
        report.append(f"- {name}: {len(d):,} regular-season plays after dropping no-plays; "
                      f"duplicate play ids: {d.play_id.duplicated().sum()}")
    report.append(f"- NCAA exact duplicate rows dropped (feed duplicates): "
                  f"{cfb.attrs.get('exact_dups_dropped', 0):,}")
    assert not nfl.play_id.duplicated().any() and not cfb.play_id.duplicated().any()

    # FG attempts: drop rows missing down or distance (rule 2); XPs/2pt are separate play types.
    # DECISION: also drop impossible distances (<18 or >75 yds; feed typos, a few per season).
    fg_parts, fg_drops = [], []
    for d in (nfl, cfb):
        fg = d[d.is_fg]
        missing = fg.down.isna() | fg.kick_distance.isna()
        impossible = ~missing & ~fg.kick_distance.between(18, 75)
        fg_drops.append((fg.league.iloc[0], int(missing.sum()), int(impossible.sum())))
        fg_parts.append(fg[~missing & ~impossible])
    fg = finalize(pd.concat(fg_parts, ignore_index=True))
    fg["decision"] = "kick"

    # 4th-down decisions: pass/run/punt/FG on 4th down, excluding kneels and spikes (rule 6).
    fd = pd.concat([nfl, cfb], ignore_index=True)
    fd = fd[(fd.down == 4) & fd.decision.notna() & ~fd.kneel_spike]
    fd = finalize(fd)

    fg_out = fg[SCHEMA + ["dist_source"]].sort_values(["league", "season", "week", "game_id"])
    fd_out = fd[SCHEMA].drop(columns=["made", "blocked", "kick_distance", "kicker_id", "kicker_name"])
    fd_out = fd_out.sort_values(["league", "season", "week", "game_id"])
    fg_out.to_csv(CLEAN / "fg_attempts.csv", index=False)
    fd_out.to_csv(CLEAN / "fourth_down_decisions.csv", index=False)

    # ---- report
    report += ["", "## Dropped rows", ""]
    report += [f"- {lg} FG attempts dropped: {m} missing down/distance, {i} impossible distance"
               for lg, m, i in fg_drops]

    report += ["", "## FG attempts by league and season", ""]
    t = fg_out.groupby(["league", "season"]).agg(
        games=("game_id", "nunique"), attempts=("made", "size"), fg_pct=("made", "mean"),
        avg_dist=("kick_distance", "mean"), att_50plus=("kick_distance", lambda x: (x >= 50).sum()),
        att_60plus=("kick_distance", lambda x: (x >= 60).sum()), blocked=("blocked", "sum"),
        kicker_id_coverage=("kicker_id", lambda x: x.notna().mean()))
    t["fg_pct"] = (t.fg_pct * 100).round(1)
    t["avg_dist"] = t.avg_dist.round(1)
    t["kicker_id_coverage"] = t.kicker_id_coverage.round(2)
    report += [t.to_markdown(), ""]

    report += ["## 4th-down decisions by league and season", ""]
    t4 = fd_out.groupby(["league", "season"]).decision.value_counts().unstack(fill_value=0)
    t4["total"] = t4.sum(axis=1)
    t4["go_pct"] = (t4["go"] / t4.total * 100).round(1)
    report += [t4.to_markdown(), ""]

    report += ["## Missing values in key columns (share of rows)", ""]
    key = ["kick_distance", "down", "ydstogo", "yardline_100", "score_diff", "wp",
           "game_seconds_remaining", "kicker_id", "dome", "temp", "wind"]
    miss = fg_out.groupby("league")[key].apply(lambda g: g.isna().mean()).round(3).T
    report += ["FG attempts:", "", miss.to_markdown(), ""]
    key4 = ["down", "ydstogo", "yardline_100", "score_diff", "wp", "game_seconds_remaining"]
    miss4 = fd_out.groupby("league")[key4].apply(lambda g: g.isna().mean()).round(3).T
    report += ["4th-down decisions:", "", miss4.to_markdown(), ""]
    report += ["Note: NFL `temp`/`wind` are missing by design for dome/closed-roof games. "
               "College has no roof/weather fields in the cfbfastR play-by-play.", ""]

    report += ["## College distance source", ""]
    src = fg_out[fg_out.league == "NCAA"].groupby("season").dist_source.value_counts().unstack(fill_value=0)
    report += [src.to_markdown(), ""]
    rng = fg_out.groupby("league").kick_distance.agg(["min", "max"])
    report += ["Distance range:", "", rng.to_markdown(), ""]

    # Sanity checks vs brief section 6.1
    report += ["## Sanity checks against the project brief (NFL)", ""]
    expected = {2024: (1115, 84.0, 40.1, 279, 3826, 20.0), 2025: (1088, 85.6, 40.5, 266, 3793, 23.3)}
    rows = ["| Season | Metric | Expected | Got | OK |", "|---|---|---|---|---|"]
    for s, exp in expected.items():
        f = fg_out[(fg_out.league == "NFL") & (fg_out.season == s)]
        q = fd_out[(fd_out.league == "NFL") & (fd_out.season == s)]
        got = (len(f), round(f.made.mean() * 100, 1), round(f.kick_distance.mean(), 1),
               int((f.kick_distance >= 50).sum()), len(q), round((q.decision == "go").mean() * 100, 1))
        names = ["FG attempts", "FG %", "Avg distance", "50+ attempts", "4th-down plays", "Go-for-it %"]
        for n, e, g in zip(names, exp, got):
            rows.append(f"| {s} | {n} | {e} | {g} | {'yes' if abs(e - g) < 0.051 else 'NO'} |")
    report += rows + [""]

    (OUT / "data_quality_report.md").write_text("\n".join(report))
    print("\n".join(report))


if __name__ == "__main__":
    main()
