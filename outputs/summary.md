# Did the NFL's 2025 K-Ball Rule Change Improve Kicking, or Are Kickers Just Getting Better?

EXSS 327 Final Project, Team 2: Bennett Vitagliano, Freddie Mills, Adam Hesketh, Jessica Fan, Anabeth Tomalis

## Bottom line

NFL kicking did change in 2025: kicks were longer, and accuracy rose slightly once distance is
accounted for. But college football, which had no K-ball rule change, improved by about as much over
the same period. Comparing the two leagues, we find **no statistically detectable NFL-specific 2025
effect** on accuracy, attempt distance, long-attempt share or 4th-down decisions. The data are more
consistent with kickers generally getting better (plus normal year-to-year noise) than with a large
K-ball effect, though modest effects on distance cannot be ruled out.

## Data and design

- **NFL:** nflverse play-by-play, regular season, 2018-2025 (25,828 FG attempts across both leagues in 2018-2025;
  NFL 2024 and 2025 totals reproduce the published numbers exactly, e.g. 1,088 attempts, 85.6%, 40.5 yds in 2025).
- **College (control group):** cfbfastR play-by-play, regular-season games between two FBS teams.
  We confirmed from the NCAA's April 2025 rules report that college made no ball or field-goal rule change in 2025.
- **Design:** difference-in-differences. The pre period is 2021-24 and the post period is 2025. The
  "K-ball effect" is the NFL's change minus college's change, estimated with logit/linear models,
  season fixed effects and standard errors clustered by game. Accuracy models account for
  each league's own make-rate-by-distance curve.
- **Parallel trends:** using only 2018-24 data, NFL and college moved together on every outcome
  (no outcome met our pre-set "clearly not parallel" rule). One warning: the NFL's share of 50+ yard
  attempts was already growing faster than college's before 2025.

## Answers to the research questions

**RQ1: Did NFL kicking change in 2025?** Yes, modestly. Compared with 2021-24:

| NFL, 2025 vs 2021-24 | Change [95% CI] |
|---|---|
| Attempt distance | **+1.3 yds** [+0.5, +2.0], p = 0.001 |
| Share of attempts from 50+ yds | **+3.0 pp** [+0.1, +5.8], p = 0.04 |
| Make rate, distance-adjusted | +1.9 pp [-0.2, +4.1], p = 0.08 |
| Make rate, raw | +0.6 pp [-1.7, +2.8], p = 0.62 |

Raw accuracy barely moved because kickers attempted longer kicks. 60+ yard attempts went 12/22 in 2025,
compared with 18/46 across all four seasons 2021-24, but 22 kicks is too few to draw conclusions from.

**RQ2: Was the NFL's change larger than college's?** No. College also improved:
distance-adjusted make rate +2.8 pp [+1.1, +4.6] and attempt distance +0.9 yds [+0.4, +1.3] (fig. 7).
The NFL-minus-college estimates:

| NFL-specific 2025 effect (DiD) | Estimate [95% CI] | p (Holm-adjusted, 5 planned tests) |
|---|---|---|
| Make rate (distance-adjusted) | -0.1 pp [-2.5, +2.4] | 1.00 |
| Attempt distance | +0.4 yds [-0.4, +1.3] | 1.00 |
| Share of attempts 50+ yds | +0.9 pp [-3.0, +4.7] | 1.00 |

The accuracy result is tight enough to rule out an NFL-specific gain larger than about 2.4 percentage points.

**RQ3: Did NFL teams kick more on 4th down?** No evidence of this. In long-FG range (opponent's 30-55,
5 or fewer yards to go), the NFL-specific change in kicking was -2.7 pp [-6.9, +1.4] and in going for it
+0.9 pp [-4.5, +6.2]. The NFL's overall go-for-it rate did rise (20.0% in 2024 to 23.3% in 2025), but
college's rose too (25.4% to 27.2%), so this looks like the continuing league-wide move toward
aggressiveness rather than a response to better kicking.

**RQ4: Is the effect concentrated in long kicks?** No. NFL-specific accuracy effects by distance were
+0.3 pp [-6.2, +6.8] at 50-59 yds and -3.1 pp [-26.8, +20.5] at 60+ (fig. 9). The 60+ category has
only 22 NFL and 7 college attempts in 2025, so it cannot answer the question either way.

**Same-kicker check (NFL only).** For 27 kickers with 15+ attempts both before and in 2025, accuracy
relative to expectation did not change (+0.0 pp [-2.8, +2.9]), but they kicked from 1.4 yds farther
on average [+0.5, +2.3]; 78% kicked longer (fig. 10). Results are the same at 10 and 20 attempt thresholds.
So the same kickers attempted longer kicks without making them at a higher-than-expected rate.

## Robustness (fig. 8)

Every alternative specification gives a confidence interval that includes zero:
- baselines 2018-24 with and without 2020, and 2023-24 only;
- allowing an NFL-specific pre-trend;
- linear probability models;
- excluding blocked kicks;
- NFL dome, temperature and wind controls;
- a wider 4th-down sample.

A placebo that pretends the rule started in 2024 is also null. Note that 2024 was a weak NFL kicking year
(-1.7 pp relative to college), which makes a simple 2024-to-2025 comparison look better than the
multi-year comparison. **The one fragile result is distance:** if college kick distance is measured from
field position rather than the play text (the two disagree by about a yard from 2025 week 9 on), the
NFL-specific distance effect grows to +0.7 yds [-0.1, +1.6] (p = 0.10) and the 50+ share effect to
+2.6 pp [-1.1, +6.4]. Neither is significant, but a modest K-ball effect on distance is plausible.

**Exploratory 2026 (weeks 1-8, in progress):** NFL accuracy is 83.7% vs 84.4% over the same weeks of
2025; mean distance is 41.1 vs 41.3 yds. The longer kicks have persisted, but there is no sign of a further
accuracy gain, consistent with the Chicago Sun-Times observation that 2026 is not matching 2025.

## How unusual is 2025? Placebo years and bootstrap (fig. 11)

Because there is only one post season, we checked how much the NFL-minus-college gap moves in ordinary
years. We treated each season 2018-2024 as a fake rule year (compared with the other pre-2025 seasons)
and compared the real 2025 estimate with these seven placebo estimates:
- **2025 does not stand out on any outcome.** For accuracy, 2025 (+0.2 pp) is the *smallest* of the eight
  estimates in absolute size. For distance, 2025 (+0.4 yds) ranks 3rd of 8; 2022 was larger (+1.0 yds).
  Permutation p-values range from 0.38 to 1.00.
- **Ordinary seasons swing more than our confidence intervals assume.** For four of the five outcomes,
  estimates vary 1.2-1.5 times more across seasons than game-clustered standard errors imply (4th-down
  go-for-it is the exception). For example, 4 of 35 placebo estimates look "significant" even though no
  rule changed. Using the season-to-season spread instead gives wider ranges for 2025, e.g. accuracy
  -3.3 to +3.6 pp and distance -0.6 to +1.4 yds. This strengthens the null result:
  even a borderline "significant" 2025 estimate would not have been convincing.
- **The bootstrap gives the same answer.** Resampling games (999 replications) gives intervals almost identical
  to the model-based ones, e.g. accuracy -2.4 to +2.1 pp and distance -0.4 to +1.3 yds, so those were not the
  weak point. Season-level variation was.

We did not use cross-validation. It measures prediction accuracy, and our question is an estimate of a
single effect, not a prediction.

## Limitations

- **One post season.** Effects are estimated from a single season; small effects (and anything at 60+ yds) are
  hard to detect. Placebo years show ordinary seasons vary more than standard errors assume (see above),
  and with seven placebo seasons, a permutation test can never reach p < 0.05 (minimum p = 0.125).
- **College as a control assumes similar trends without the rule.** Pre-trends looked parallel, but the tests
  have limited power (4-7 seasons), and NFL and college differ in talent, hash marks and coaching choices.
  Any college-specific change in 2025 would bias the comparison.
- **Data pipelines differ.** NFL and college data come from different sources. The college feed changed format
  mid-2025, which shifts college kick distance by about a yard (see robustness). College play IDs were
  unusable, and 4,829 duplicate rows were removed.
- **The NFL change is a bundle.** The 2025 NFL season also had kickoff and other rule changes, so we can
  estimate a "2025 NFL effect", not one that is uniquely due to the ball.
- **Attempt distance is a coaching choice** as well as a measure of kicker ability.
- **Survivorship.** The same-kicker check includes only kickers who stayed in the league, and has no control group.
- **Observational data** cannot prove causation. The four hypotheses were planned in advance; robustness,
  placebo-year, bootstrap and 2026 results are exploratory.

## Reproducibility

All code is in `src/` (R) and runs from raw downloads to these results. Cleaning decisions are listed in
`README.md`; full tables are in `outputs/data_quality_report.md`, `outputs/pretrends_report.md`, `outputs/inference_report.md` and
`outputs/models_report.md`; figures are in `outputs/figures/`.
