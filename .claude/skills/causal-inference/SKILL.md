---
name: Causal Inference
description: Design, implement, or review causal-inference analyses (DiD, event studies, synthetic DiD, RCTs, IV, RDD) in this template's R pipeline. Use when writing R/04_analysis.R, choosing estimators, specifying fixed effects, clustering, robustness checks, or interpreting treatment effects.
---

# Causal Inference

## Estimator choice

- Two-period or uniform-timing DiD: `fixest::feols` with explicit unit and time fixed effects.
- Staggered adoption: do NOT use plain two-way fixed effects. Use Callaway–Sant'Anna (`did` package) or Sun–Abraham (`fixest::sunab`), and state the comparison (clean control) group.
- Few treated units / aggregate policy: synthetic DiD (`synthdid`) or synthetic control; report placebo-based inference.
- Count outcomes: Poisson pseudo-maximum-likelihood (`fixest::fepois`), not log-linear OLS. Note that PPML handles zeros and is consistent under a correctly specified conditional mean.
- RCT: ANCOVA (outcome on treatment + baseline outcome) is preferred over difference-in-means or change scores.
- IV: report first-stage F; be explicit about the exclusion restriction in economic terms.
- RDD: show the McCrary density test and a bandwidth-robustness plot.

## Mandatory checks

1. Plot raw outcome means by group over time before running any regression.
2. Event-study / pre-trend plot for any DiD claim; report a joint test of the pre-period coefficients.
3. Justify the clustering level in a code comment (cluster at the level of treatment assignment). With few clusters (< 40), use wild cluster bootstrap (`fwildclusterboot`) or randomization inference.
4. Include at least one placebo test (fake treatment date or fake treated group).
5. Report the number of units, clusters, and observations in every table.

## Reporting

- Always report economic magnitudes (percent effects, effects relative to the control mean), not only coefficients and stars.
- Every headline estimate gets a table row and, where dynamics matter, an event-study figure.
- State the identifying assumption in one sentence near the main result, and say what evidence supports it.
- Do not present a causal interpretation the design cannot support; flag it as associational instead.

## Known project-specific pitfalls

- Zeros in billing/consumption data may reflect billing censoring, not true zero consumption. Investigate before treating them as outcomes.
- Heating-fuel or infrastructure differences can confound regional treatment comparisons. Check covariate balance across regions/districts.
- With large data, load selectively (Arrow/parquet, column selection) to stay RAM-lean.

## Learning check

Before finalizing a design, briefly confirm the user understands the key identifying assumption and why the chosen estimator fits (see the `mentor-and-learning` skill). Do not let an estimator choice go unexplained.
