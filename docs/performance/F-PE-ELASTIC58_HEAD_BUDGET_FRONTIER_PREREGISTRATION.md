# F-PE-ELASTIC58 — mode-7 head-budget frontier preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent branch head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen conservative scaling:
`alpha = 0.17320259355765216`.

## Question

What acceptance/refinement/error frontier results when the qualified C-SAFE
controller pattern is evaluated over a fixed logarithmic family of positive
head-error budgets?

ELASTIC58 does not select a production budget.

## Why a frontier, not a chosen tolerance

Canonical F-CI14 contains no independently qualified numeric temporal limits.

The Richards literature supports adaptive error control but does not provide one
universally transferable pressure-head tolerance for SWAP5.

Therefore ELASTIC58 characterizes a fixed budget family rather than inventing a
single authoritative physical threshold.

## Frozen budgets

Head budgets in cm:

- 0.01
- 0.03
- 0.1
- 0.3
- 1.0
- 3.0
- 10.0

These are characterization points only.

No budget may be selected or modified after seeing results.

## Frozen bank

Reuse the complete ELASTIC55/56/57 four-profile bank:
- profiles 11060, 10260, 8016, 3030;
- same materialization;
- same states and forcing;
- OFF, FIXED_1E6, GENERATED;
- same nine-dt ladder;
- same research mode-7 indicator;
- same frozen alpha;
- same C-SAFE rule.

For every profile/state/forcing/regime sequence and each fixed budget:
1. traverse dt from largest to smallest;
2. skip unavailable full solve/indicator points;
3. compute `E = alpha * Binf`;
4. accept the first point with `E <= budget`;
5. if no point passes, return EXHAUSTED.

## Observations per budget

Record:
- number and fraction accepted;
- number and fraction exhausted;
- accepted retry-index distribution;
- mean/median accepted retry index;
- mean attempted ladder points before acceptance/exhaustion;
- number of accepted observations with paired full/two-half reference;
- maximum and median realized `H_INF` among paired accepted cases;
- maximum realized `H_INF / budget`;
- maximum realized `H_INF / (alpha*Binf)`;
- accepted counts by regime and initial-state class.

## Hard gates

A1. Parent four-profile bank and O0/O2 semantics reproduce.

A2. C-SAFE never accepts unavailable points.

A3. C-SAFE never accepts `alpha*Binf > budget`.

A4. Every paired accepted point satisfies the frozen global envelope
`H_INF <= alpha*Binf`.

A5. Budget ordering is weakly monotone in acceptance count:
larger budget may not accept fewer sequences than a smaller budget.

A6. No alpha refit.

A7. Zero `src/**` production changes.

## Interpretation boundary

ELASTIC58 may identify:
- dominated budget regions;
- steep accuracy/refinement trade-offs;
- budgets that are impractically strict or permissive on this bank.

It may not declare a production temporal tolerance because that requires an
independent application-level accuracy decision.

## Decision

A green result qualifies a head-budget frontier only.

If the frontier exhibits a clear knee, that may justify a later bounded
candidate-budget qualification. If not, the remaining blocker is an explicit
application-level accuracy requirement rather than numerical method behavior.
