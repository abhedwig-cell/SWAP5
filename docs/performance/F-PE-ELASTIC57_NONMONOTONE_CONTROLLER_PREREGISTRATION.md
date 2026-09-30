# F-PE-ELASTIC57 — non-monotone-safe mode-7 controller replay preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC56 — QUALIFIED_LOCALIZED_BINF_NONMONOTONICITY_WITH_GLOBAL_ENVELOPE_PRESERVED`

Parent postimage:
`research/f-pe-elastic56-monotonicity-attribution@39237db54f0a8ee6d0bb9548fdf367828df0f975`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Frozen conservative relation:
`H_INF <= alpha * Binf`,
with
`alpha = 0.17320259355765216`.

## Question

Can a minimal retry controller remain safe and operational when the mode-7
indicator is locally non-monotone?

## Candidate controller

Research-only threshold-halving logic:

1. start at the largest frozen dt;
2. if the full solve fails or Binf is unavailable, halve dt;
3. otherwise compute `predicted_head_bound = alpha * Binf`;
4. accept the first dt for which `predicted_head_bound <= head_budget`;
5. if the indicator increases after halving, do not extrapolate and do not
   enlarge dt; simply continue the frozen halving sequence;
6. if no dt satisfies the budget within the frozen ladder, return exhausted.

The candidate never assumes that Binf decreases monotonically.

It does not modify solver, mass acceptance, transaction rollback, ELAS physics
or production source.

## Frozen bank

Replay the ELASTIC55/56 four-profile bank exactly:
- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder from 0.015625 day by factor 0.5.

## Research head-budget sweep

Use explicit sensitivity budgets:
- 0.01 cm;
- 0.03 cm;
- 0.10 cm;
- 0.30 cm.

These are research stress-test values only, not production temporal limits.

## Safety oracle

For every controller acceptance where a paired full/two-half H_INF exists:
- require `H_INF <= head_budget`.

This is an observational oracle only.
The controller itself may use only `alpha * Binf`, never H_INF.

## Comparisons

Classify each profile/state/forcing/regime sequence as:
- MONOTONE;
- NONMONOTONE_CONTIGUOUS/GAP according to ELASTIC56.

For each budget record:
- accepted/exhausted;
- accepted retry index and dt;
- number of full-solve failures skipped;
- number of indicator increases encountered before acceptance/exhaustion;
- realized H_INF at accepted point when paired;
- head-budget safety margin.

## Hypotheses

H1. The threshold-only halving controller produces no paired false acceptance
across the full replay bank.

H2. Non-monotone sequences may require extra halvings but do not require a
different acceptance rule.

H3. The localized ELASTIC56 nonmonotonicity does not create oscillation because
the candidate never increases dt within an interval retry sequence.

H4. Some strict budgets may exhaust the frozen ladder; exhaustion is a safe
result, not a failure of the controller contract.

## Gates

A1. Same four ELASTIC55 profiles are replayed.

A2. Same 1728 physical cases execute with O0/O2 semantic identity.

A3. Frozen alpha is used exactly and never refit.

A4. Controller decisions depend only on full-solve status, indicator
availability, Binf and the research head budget.

A5. Every paired accepted point satisfies the independent H_INF budget oracle.

A6. No sequence can revisit or increase dt; retry index is strictly increasing.

A7. Zero `src/**` production changes.

## Decision

ELASTIC57 may qualify a research-only non-monotone-safe controller contract.

It does not authorize:
- a production head budget;
- mode-7 production temporal admission;
- replacement of the current production temporal gate;
- default-on ELAS;
- a timestep growth policy.
