# Presentation brief: NFL K-Ball Rule Project (for building slides and visuals)

> **Instructions for Claude (paste this whole document):**
> Build a 12-13 slide presentation deck (16:9) for a university course final project, using the slide plan
> and data below. Rebuild every chart from the data tables in this document (they are exact). If PNG figures
> are attached, use them for reference only. Rules:
> 1. **Use only the numbers in this document.** Do not round differently, invent figures or add outside statistics.
> 2. **Do not overclaim.** The finding is "no detectable NFL-specific effect", not "the K-ball rule did nothing".
>    See "Claims to avoid" below.
> 3. Follow the design spec (colors, one y-axis per chart, highlight 2025, show uncertainty as bars).
> 4. Keep slide text short: one headline sentence plus at most 3 bullets. Put detail in speaker notes.
> 5. Audience: classmates and an instructor in an exercise and sport science course. Explain statistics in plain language.

---

## 1. Project at a glance

- **Course:** EXSS 327 Final Project, Team 2
- **Team:** Bennett Vitagliano, Freddie Mills, Adam Hesketh, Jessica Fan, Anabeth Tomalis
- **Title:** *Did the NFL's 2025 K-Ball Rule Change Improve Kicking, or Are Kickers Just Getting Better?*
- **Background:** Before 2025, NFL teams got the kicking balls ("K-balls") only shortly before kickoff. In March 2025
  owners voted 31-1 to let teams prepare K-balls well ahead of games. Kickers say broken-in balls are softer and fly
  farther. In 2025 the league average attempt distance hit 40.5 yards (the highest in our 2018-2025 data; reported in
  the media as an all-time high), and 60+ yard field goals went 12 of 22, up from 4 of 15 in 2024.
- **The problem:** NFL kicking has been improving for years, so a before/after comparison can't separate the ball
  from the trend.
- **Our approach:** Use **college football (FBS)** as a comparison group. College made no ball or field-goal rule change
  in 2025 (confirmed in the NCAA's official April 2025 rules report). If the NFL improved *more than college did*, that
  points to the K-ball. If both improved equally, that points to kickers just getting better.

## 2. The one-sentence takeaway

**NFL kicking did get longer (and slightly more accurate) in 2025, but college football improved by about as much
with no rule change, so we find no detectable K-ball effect. The evidence fits "kickers are just getting better".**

Supporting points:
1. NFL attempt distance rose 1.3 yards (statistically significant), but college rose 0.9 yards too. The NFL-only part (+0.4) is not significant.
2. Accuracy (adjusted for distance): NFL +1.9 points, college +2.8 points. The NFL-specific effect is -0.1 points.
3. Compared with seven earlier "fake rule" seasons, 2025 doesn't look unusual on any measure.

## 3. Plain-language glossary (for slides or speaker notes)

- **Difference-in-differences (DiD):** (NFL change) minus (college change). It removes improvements both leagues share.
- **pp (percentage points):** 85% to 87% is +2 pp.
- **Distance-adjusted accuracy:** make rate after accounting for how long the kicks were (longer kicks are harder).
- **95% CI (confidence interval):** the range of plausible values. If it crosses zero, we can't rule out "no effect".
- **Placebo year:** pretend the rule started in an earlier year (when nothing changed) and run the same analysis.
  This shows how big "effects" look in ordinary years.
- **Parallel trends:** before 2025, did the NFL and college move together? If yes, college is a fair comparison.

## 4. Data and methods (for a methods slide)

- **NFL data:** nflverse play-by-play. **College data:** cfbfastR play-by-play (FBS vs FBS games only). Regular season.
- **Main comparison:** 2021-2024 (before) vs 2025 (after). 17,037 field-goal attempts
  (NFL 5,352; college 11,685) and 9,917 4th-down decisions in long-field-goal range.
- **Models:** logistic/linear regression with season effects, standard errors grouped by game; results reported in pp or yards.
- **Checks:** pre-2025 trend test, 10 alternative specifications, placebo years, bootstrap (999 resamples), same-kicker
  comparison (27 NFL kickers), and an early look at the 2026 season.
- **Validation:** our NFL counts reproduce published 2024/2025 totals exactly (e.g. 2025: 1,088 attempts, 85.6%, 40.5 yds).

---

## 5. Slide-by-slide plan

### Slide 1: Title
- Title: *Did the K-Ball Rule Change NFL Kicking, or Are Kickers Just Getting Better?*
- Subtitle: EXSS 327 Final Project, Team 2; team names.
- Visual idea: a football on a kicking tee, or a minimal goalpost line graphic (no photos needed).

### Slide 2: The K-ball rule and the hype
- Headline: **"2025 looked like a record year for NFL kickers"**
- Bullets: the rule (teams can prepare K-balls ahead of time; approved 31-1, March 2025); avg attempt 40.5 yds (highest in
  our data); 60+ yarders 12/22 in 2025 vs 4/15 in 2024.
- Optional mini visual: two big stat tiles, "40.5 yds avg attempt" and "12 of 22 from 60+".

### Slide 3: Research questions
- RQ1: Did NFL accuracy and distance change in 2025?
- RQ2: Was the NFL's change bigger than college's? (the key test)
- RQ3: Did NFL teams kick more on 4th down?
- RQ4: Is any effect concentrated in long (50+, 60+) kicks?

### Slide 4: Our approach (college as a comparison group)
- Headline: **"Compare the NFL's change to college's change"**
- Visual: a simple diagram, e.g. NFL change (+) minus college change (+) = K-ball effect (?).
  Or two arrows ("NFL 2021-24 to 2025", "College 2021-24 to 2025") feeding into "Difference = NFL-specific effect".
- Bullets: college had no ball rule change in 2025; 17,037 FG attempts, 2021-2025; regular season.

### Slide 5: Kicking was getting longer before 2025, in both leagues (CHART A)
- Headline: **"Kicks were already getting longer, in the NFL and in college"**
- Chart A: line chart of mean attempt distance by season, NFL vs college, 2018-2025, 2025 shaded as "K-ball rule".
- Speaker note: the NFL hit 40.5 yds in 2025, but it was already at 40.1 in 2024; college rose from 35.6 to 37.5 since 2018.

### Slide 6: Is college a fair comparison? (CHART B)
- Headline: **"Before 2025, the NFL and college moved together"**
- Chart B: two-panel dot-and-error-bar chart of the NFL-minus-college gap by year relative to 2024 (accuracy; distance).
  Points near zero = moved together.
- Speaker note: no outcome failed our pre-set test. One caution: the NFL's share of 50+ yd attempts was already growing faster.

### Slide 7: MAIN RESULT (CHART C)
- Headline: **"The NFL improved in 2025, but so did college"**
- Chart C: dot plot with 95% CI bars, 3 panels (accuracy, distance, 50+ share), NFL and college rows, value labels.
- Bullets / callout: NFL-specific effect: accuracy -0.1 pp, distance +0.4 yds, 50+ share +0.9 pp. None significant.
- This is the most important slide. If only one chart is used, use this one.

### Slide 8: Long kicks (RQ4) (CHART D)
- Headline: **"No sign the effect is concentrated in long kicks"**
- Chart D: NFL-specific accuracy effect by distance bin with CIs. Cap the y-axis at about +/-10 and mark that the 60+
  bar extends off the chart (its CI is -26.8 to +20.5).
- Bullet: 60+ kicks are too rare to judge (22 NFL and 7 college attempts in 2025).

### Slide 9: 4th-down strategy (RQ3) (CHART E)
- Headline: **"Teams are going for it more, in both leagues"**
- Chart E: line chart of go-for-it rate on 4th down by season, NFL vs college, 2025 shaded.
- Bullets: NFL 20.0% to 23.3% (2024 to 2025); college 25.4% to 27.2%. In long-FG range, no NFL-specific shift toward kicking (-2.7 pp, not significant).

### Slide 10 (optional): Same kickers, before vs after (CHART F)
- Headline: **"The same kickers tried longer kicks, but weren't more accurate than expected"**
- Chart F: two scatter plots (27 kickers): FG% over expected 2021-24 vs 2025; mean distance 2021-24 vs 2025; dashed 45-degree line.
- Bullets: +1.4 yds farther on average (78% kicked longer, significant); accuracy over expected +0.0 pp.

### Slide 11: "But it's only one season" (CHART G)
- Headline: **"2025 looks like an ordinary year"**
- Chart G: for accuracy and distance (2 panels), dot-and-error-bar estimates for each placebo year 2018-2024 (gray)
  and 2025 (blue).
- Bullets: for accuracy, 2025 is the smallest of the 8 estimates; for distance, 2022 had a bigger fake "effect" than 2025.
  Bootstrap (999 resamples) gives the same intervals.

### Slide 12: Conclusion
- Headline: **"Kickers are getting better, and the K-ball can't take the credit (yet)"**
- RQ1: Yes, NFL kicks got longer (+1.3 yds) and accuracy rose slightly (+1.9 pp, distance-adjusted, not significant).
- RQ2: No, college improved about as much (NFL-specific effect about zero).
- RQ3/RQ4: No NFL-specific shift in 4th-down kicking; no concentration in long kicks (too few 60+ kicks to judge).
- Early 2026 (weeks 1-8): kicks still long (41.1 yds) but accuracy not higher (83.7% vs 84.3% in the same weeks of 2025).

### Slide 13: Limitations and why it matters
- Limitations: only one post-rule season; college differs from the NFL; other 2025 NFL rule changes (e.g. kickoffs);
  college data feed changed mid-2025 (shifts college distance by about 1 yd; with the alternative measure the NFL-specific
  distance effect is +0.7 yds, p = 0.10); observational data.
- Why it matters: 4th-down decision analytics; sports betting props (longest FG, made FGs, kicking points);
  evaluating whether equipment rules change performance.

### Backup slides (if asked)
- **Robustness:** all 10 alternative specifications include zero (table in section 6.8).
- **Raw make rate by distance bin**, 2021-24 vs 2025 (section 6.9).
- **2026 exploratory** (section 6.10).

---

## 6. Data for every chart (exact values)

### 6.1 Season table (Charts A and E, plus stat tiles)

| League | Season | FG attempts | FG % | Mean distance (yds) | Share 50+ (%) | 60+ made/att | 4th-down go-for-it (%) |
|---|---|---|---|---|---|---|---|
| College | 2018 | 2,177 | 73.0 | 35.6 | 7.5 | 0/2 | 21.0 |
| College | 2019 | 2,232 | 74.3 | 35.7 | 7.8 | 1/1 | 21.4 |
| College | 2020 | 1,494 | 73.8 | 36.4 | 9.4 | 0/1 | 23.6 |
| College | 2021 | 2,281 | 74.8 | 36.2 | 9.9 | 2/4 | 23.7 |
| College | 2022 | 2,264 | 76.7 | 35.8 | 8.0 | 1/2 | 24.5 |
| College | 2023 | 2,375 | 74.8 | 36.9 | 10.4 | 2/3 | 24.0 |
| College | 2024 | 2,364 | 75.9 | 37.6 | 13.6 | 5/12 | 25.4 |
| College | 2025 | 2,401 | 77.1 | 37.5 | 11.7 | 1/7 | 27.2 |
| NFL | 2018 | 946 | 84.8 | 38.5 | 16.1 | 2/5 | 14.8 |
| NFL | 2019 | 982 | 81.7 | 38.2 | 14.7 | 2/4 | 16.2 |
| NFL | 2020 | 960 | 84.6 | 38.9 | 17.5 | 1/10 | 19.1 |
| NFL | 2021 | 1,027 | 85.1 | 38.6 | 17.7 | 4/9 | 20.9 |
| NFL | 2022 | 1,062 | 85.0 | 39.3 | 21.1 | 5/13 | 18.8 |
| NFL | 2023 | 1,060 | 85.9 | 39.1 | 21.7 | 5/9 | 19.6 |
| NFL | 2024 | 1,115 | 84.0 | 40.1 | 25.0 | 4/15 | 20.0 |
| NFL | 2025 | 1,088 | 85.6 | 40.5 | 24.4 | 12/22 | 23.3 |

2020 = COVID-shortened college season (fewer games). Go-for-it % = share of all 4th downs (pass, run, punt, FG) that were a pass or run.

### 6.2 Chart B: NFL-minus-college gap relative to 2024 (pre-2025 data only)

Estimate [95% CI]. 2024 is the reference year (fixed at 0).

| Year | Accuracy, distance-adjusted (pp) | Attempt distance (yds) |
|---|---|---|
| 2018 | 4.41 [0.40, 8.43] | 0.40 [-0.67, 1.47] |
| 2019 | -0.51 [-4.55, 3.54] | -0.04 [-1.14, 1.05] |
| 2020 | 2.93 [-1.24, 7.11] | -0.01 [-1.16, 1.15] |
| 2021 | 2.39 [-1.43, 6.20] | -0.06 [-1.17, 1.05] |
| 2022 | 2.03 [-1.76, 5.81] | 1.03 [-0.08, 2.13] |
| 2023 | 2.77 [-1.04, 6.59] | -0.34 [-1.48, 0.80] |
| 2024 | 0 (reference) | 0 (reference) |

Note for speaker: accuracy points sit mostly above zero because 2024 was a weak NFL year relative to college. The joint
test that all these are zero is not rejected (p = 0.23 for accuracy, 0.25 for distance).

### 6.3 Chart C: each league's own change, 2025 vs 2021-24 (MAIN RESULT)

| Outcome | NFL change [95% CI] | College change [95% CI] | NFL-specific effect (DiD) [95% CI], p |
|---|---|---|---|
| Accuracy, distance-adjusted (pp) | +1.9 [-0.2, +4.1] | +2.8 [+1.1, +4.6] | -0.1 [-2.5, +2.4], p = 0.96 |
| Attempt distance (yds) | +1.3 [+0.5, +2.0] | +0.9 [+0.4, +1.3] | +0.4 [-0.4, +1.3], p = 0.35 |
| Share of attempts 50+ yds (pp) | +3.0 [+0.1, +5.8] | +1.2 [-0.2, +2.6] | +0.9 [-3.0, +4.7], p = 0.66 |

Raw (not distance-adjusted) accuracy change: NFL +0.6 pp, college +1.6 pp. All five planned tests remain
non-significant after Holm correction (adjusted p >= 0.97).

### 6.4 Chart D: NFL-specific accuracy effect by distance (DiD), 2025 vs 2021-24

| Distance | Effect (pp) [95% CI] | NFL attempts 2021-24 / 2025 | College attempts 2021-24 / 2025 |
|---|---|---|---|
| Under 40 | -0.6 [-2.7, +1.4] | 2,162 / 509 | 5,517 / 1,337 |
| 40-49 | +0.9 [-3.5, +5.2] | 1,187 / 313 | 2,794 / 784 |
| 50-59 | +0.3 [-6.2, +6.8] | 869 / 244 | 952 / 273 |
| 60+ | -3.1 [-26.8, +20.5] | 46 / 22 | 21 / 7 |

### 6.5 Chart E: 4th-down go-for-it rate. Use the last column of table 6.1.
Model result (long-FG range: opponent's 30-55 yard line, 5 or fewer yards to go): NFL-specific change in kicking
-2.7 pp [-6.9, +1.4], p = 0.19; in going for it +0.9 pp [-4.5, +6.2], p = 0.75.

### 6.6 Chart F: same 27 NFL kickers (15+ attempts in 2021-24 and in 2025)

FGOE = FG% over expected (made rate minus expected rate for those distances, using the NFL 2021-24 curve), in pp.

| Kicker | Att 2021-24 | Att 2025 | FGOE 2021-24 | FGOE 2025 | Mean dist 2021-24 | Mean dist 2025 |
|---|---|---|---|---|---|---|
| B.Aubrey | 85 | 42 | 7.4 | 6.2 | 41.7 | 43.3 |
| B.Grupe | 68 | 37 | -0.3 | -6.0 | 40.2 | 39.8 |
| B.McManus | 125 | 30 | 0.4 | -6.6 | 40.9 | 37.5 |
| C.Boswell | 143 | 32 | 4.6 | 4.9 | 40.3 | 43.3 |
| C.Dicker | 97 | 41 | 8.4 | 7.0 | 38.7 | 39.0 |
| C.Little | 29 | 34 | 7.8 | 6.7 | 38.4 | 42.4 |
| C.McLaughlin | 120 | 38 | 2.8 | 3.0 | 39.9 | 42.4 |
| C.Ryland | 57 | 33 | -8.0 | -6.1 | 39.4 | 42.3 |
| C.Santos | 116 | 30 | 3.8 | -0.3 | 39.3 | 41.1 |
| D.Carlson | 150 | 27 | 3.7 | -0.4 | 38.4 | 42.0 |
| E.McPherson | 115 | 28 | -0.7 | 8.3 | 41.3 | 42.7 |
| E.Pineiro | 98 | 29 | 3.5 | 14.2 | 38.9 | 41.7 |
| H.Butker | 112 | 38 | 0.9 | 2.1 | 38.7 | 39.2 |
| J.Bates | 29 | 34 | 7.2 | -2.0 | 41.6 | 42.2 |
| J.Elliott | 124 | 27 | 1.1 | -6.5 | 38.3 | 43.4 |
| J.Karty | 34 | 15 | -0.8 | -20.6 | 37.9 | 37.4 |
| J.Moody | 59 | 23 | -9.5 | -5.7 | 38.4 | 36.5 |
| J.Myers | 132 | 48 | 0.3 | 2.8 | 39.9 | 41.4 |
| J.Slye | 112 | 35 | -1.7 | 0.8 | 39.3 | 44.1 |
| K.Fairbairn | 120 | 48 | 4.5 | 8.2 | 39.4 | 40.9 |
| M.Gay | 142 | 23 | 2.7 | -6.9 | 39.4 | 42.8 |
| M.Prater | 101 | 20 | 2.3 | 2.5 | 41.2 | 38.1 |
| N.Folk | 128 | 29 | 6.7 | 12.8 | 38.9 | 40.7 |
| R.Patterson | 74 | 29 | -2.7 | 8.2 | 37.6 | 40.1 |
| W.Lutz | 99 | 32 | -1.2 | -0.3 | 38.5 | 36.7 |
| W.Reichard | 30 | 35 | -1.4 | 12.8 | 42.0 | 42.1 |
| Z.Gonzalez | 29 | 22 | 4.3 | 7.3 | 41.7 | 45.0 |

Summary: mean change in FGOE +0.0 pp [-2.8, +2.9] (59% improved, not significant); mean change in distance
+1.4 yds [+0.5, +2.3] (78% kicked longer, p = 0.003). Same conclusion at 10+ and 20+ attempt thresholds.
Caveat: includes only kickers who stayed in the league; no college comparison.

### 6.7 Chart G: placebo years (each year vs the other pre-2025 years; 2025 vs all of 2018-24)

Estimate [95% CI]. 2018-2024 are placebo (fake rule) years; 2025 is the real rule year.

| Year | Accuracy, distance-adjusted (pp) | Attempt distance (yds) |
|---|---|---|
| 2018 | +1.77 [-1.09, +4.63] | +0.30 [-0.48, +1.07] |
| 2019 | -3.41 [-6.22, -0.59] | -0.21 [-1.03, +0.60] |
| 2020 | +0.74 [-2.18, +3.66] | -0.17 [-1.06, +0.72] |
| 2021 | +0.43 [-2.10, +2.96] | -0.23 [-1.06, +0.60] |
| 2022 | +0.44 [-2.07, +2.96] | +1.04 [+0.22, +1.86] |
| 2023 | +1.31 [-1.22, +3.85] | -0.56 [-1.43, +0.31] |
| 2024 | -1.17 [-3.84, +1.50] | -0.17 [-1.03, +0.70] |
| **2025 (real)** | **+0.18 [-2.13, +2.50]** | **+0.42 [-0.39, +1.24]** |

Speaker notes: permutation p = 1.00 (accuracy) and 0.38 (distance). Fake-rule years sometimes look "significant"
(2019 accuracy, 2022 distance), so a single season can easily produce an apparent effect by chance.
Game bootstrap (999 resamples) of the main result: accuracy [-2.4, +2.1] pp, distance [-0.4, +1.3] yds.

### 6.8 Backup: robustness, NFL-specific effect under alternative specifications

| Specification | Accuracy (pp) | Distance (yds) | 50+ share (pp) |
|---|---|---|---|
| Main: 2021-24 vs 2025 | -0.1 [-2.5, +2.4] | +0.4 [-0.4, +1.3] | +0.9 [-3.0, +4.7] |
| Baseline 2018-24 excl. 2020 | +0.2 [-2.1, +2.5] | +0.4 [-0.4, +1.2] | +1.2 [-2.5, +4.9] |
| Baseline 2023-24 only | +0.1 [-2.6, +2.8] | +0.7 [-0.2, +1.7] | +1.6 [-2.5, +5.8] |
| Allow NFL-specific pre-trend | +0.9 [-2.8, +4.6] | +0.7 [-0.5, +1.9] | +1.4 [-4.1, +6.9] |
| College distance from field position | +0.2 [-2.2, +2.7] | +0.7 [-0.1, +1.6] | +2.6 [-1.1, +6.4] |
| Placebo: fake rule in 2024 | -1.7 [-4.5, +1.1] | -0.2 [-1.1, +0.7] | -2.8 [-7.3, +1.7] |

Also null: excluding blocked kicks (+0.5 [-1.9, +2.8]), adding NFL weather controls (-0.4 [-2.8, +2.0]), linear
probability model (-0.8 [-3.6, +1.9]).

### 6.9 Backup: raw make rate by distance, 2021-24 vs 2025 (attempts in parentheses)

| Distance | NFL 2021-24 | NFL 2025 | College 2021-24 | College 2025 |
|---|---|---|---|---|
| Under 30 | 98.0% (964) | 98.1% (210) | 91.8% (2,599) | 92.2% (637) |
| 30-39 | 93.5% (1,198) | 93.0% (299) | 80.2% (2,918) | 85.3% (700) |
| 40-49 | 78.6% (1,187) | 84.3% (313) | 64.7% (2,794) | 67.1% (784) |
| 50-59 | 70.1% (869) | 70.1% (244) | 49.1% (952) | 51.3% (273) |
| 60+ | 39.1% (46) | 54.5% (22) | 47.6% (21) | 14.3% (7) |

### 6.10 Backup: 2026 so far (exploratory; same weeks of each season)

| League | Weeks | 2024 FG% / dist | 2025 FG% / dist | 2026 FG% / dist |
|---|---|---|---|---|
| NFL | 1-8 | 86.3% / 40.1 | 84.3% / 41.3 | 83.7% / 41.1 |
| College | 1-9 | 76.3% / 37.7 | 77.2% / 37.6 | 76.3% / 37.6 |

---

## 7. Design spec

- **Colors:** NFL = blue `#2a78d6`; College = orange `#eb6834` (these two pass colorblind checks). Use them consistently
  for every chart. For "before" vs "after" bars, use a lighter tint of the same color for before (NFL `#a0c0eb`,
  college `#f6b8a0`). Placebo/neutral points: gray `#9a9893`.
- **Background** `#fcfcfb`; main text `#0b0b0b`; secondary text `#52514e`; gridlines `#e4e3df`.
- **Mark 2025** with a light gray shaded band labeled "K-ball rule" on season line charts.
- **Uncertainty:** show 95% CIs as thin vertical (or horizontal) bars; draw a zero reference line on effect charts.
- **One y-axis per chart** (never dual axes). Label lines directly at their ends; a small legend is fine too.
- **Text in charts** at least 14 pt when projected. Short chart titles that state the takeaway (e.g. "College improved too").
- Don't make text the series color: keep labels dark gray/black and let the colored mark show identity.

## 8. Claims to avoid (and what to say instead)

| Don't say | Say instead |
|---|---|
| "The K-ball rule had no effect." | "We find no detectable NFL-specific effect; small effects, especially on distance, can't be ruled out." |
| "The K-ball made 60+ yard kicks better." | "60+ kicks went 12/22, but that's too few kicks to tell apart from chance." |
| "This proves kickers are just getting better." | "The evidence fits general kicker improvement better than a ball effect." |
| "College is identical to the NFL." | "College had no ball rule change and moved in parallel with the NFL before 2025." |
| "Accuracy jumped in 2025." | "Distance-adjusted accuracy rose about 2 points in both leagues." |
| Any number not in this document | (Leave it out.) |
