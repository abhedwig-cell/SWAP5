# F-PE-ELASTIC57 — threshold-free controller robustness preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC56 — QUALIFIED_LOCALIZED_BINF_NONMONOTONICITY_WITH_GLOBAL_ENVELOPE_PRESERVED`

Frozen global conservative scaling:
`alpha = 0.17320259355765216`.

## Question

Can a refinement controller remain correct and terminating when `Binf` is
locally non-monotone, without assuming that one dt halving must reduce the
indicator?

## No new numeric temporal budget

Canonical F-CI14 explicitly has no admitted numeric temporal limits.

ELASTIC57 therefore does not invent a head budget.

For each full-converged sequence define the conservative predicted error

`E_i = alpha * Binf_i`.

Controller behavior is tested over all decision regions induced by the observed
positive `E_i` values:
- below the minimum;
- between each ordered pair of distinct values;
- above the maximum.

A representative test budget for a finite interval is its geometric mean.
This enumerates all distinct accept/reject classifications obtainable from any
positive scalar budget without calibrating a new physical tolerance.

## Frozen replay bank

Reuse the ELASTIC56/55 four-profile bank exactly:
- profiles 11060, 10260, 8016, 3030;
- same retention/geometric/generated-Ss materialization;
- same states, forcing, regimes and dt ladder;
- same mode-7 research indicator;
- same frozen alpha.

## Candidate controller C-SAFE

For a sequence ordered from largest to smallest dt:

1. attempt each frozen dt in order;
2. if the full solve/indicator is unavailable, continue to the next smaller dt;
3. if `E_i <= budget`, accept that dt;
4. otherwise continue refining;
5. if no point passes, return EXHAUSTED.

C-SAFE never assumes `E_{i+1} <= E_i`.

It never accepts a point with `E_i > budget`.

## Comparator C-MONO

For characterization only, define an unsafe monotonicity-assuming comparator:

- after a failed point at dt_i, predict smaller-dt acceptability using the
  assumption that the indicator must decrease;
- any observed increase after refinement is counted as a monotonicity-assumption
  violation.

C-MONO is not a production candidate.

## Gates

A1. Replay reproduces the four parent profiles and all physical cases.

A2. O0/O2 semantic identity.

A3. For every induced positive budget and every sequence, C-SAFE either:
- accepts the first available point satisfying `E_i <= budget`; or
- returns EXHAUSTED if no such point exists.

A4. C-SAFE never accepts an unavailable point.

A5. C-SAFE never violates the frozen global conservative envelope on paired
accepted observations.

A6. All 15 ELASTIC56 violating sequences are included, together with monotone
controls.

A7. No new alpha or physical tolerance is fitted.

A8. Zero `src/**` production changes.

## Decision

A green result qualifies only the controller logic pattern:

`refine-until-passing without monotonicity assumption`.

It does not authorize:
- a production temporal budget;
- mode-7 production indicator admission;
- production controller integration;
- changes to hard mass acceptance.
