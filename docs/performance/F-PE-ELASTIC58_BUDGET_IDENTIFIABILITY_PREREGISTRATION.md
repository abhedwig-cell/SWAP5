# F-PE-ELASTIC58 — physical temporal-budget identifiability preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@7bb1e2ca65056a37916fdd56a11a3dac20cf665a`

Frozen conservative scaling:
`alpha = 0.17320259355765216`.

## Question

Can one unique physical temporal head budget be identified from the currently
qualified numerical evidence alone?

## Canonical constraint

F-CI14 explicitly contains no qualified numeric temporal limits.

ELASTIC58 therefore does not choose, fit or recommend a physical head budget.

## Frozen replay bank

Reuse the complete ELASTIC55-57 four-profile bank:
- profiles 11060, 10260, 8016, 3030;
- all frozen states, forcings, regimes and nine-dt ladders;
- same mode-7 research indicator;
- same frozen alpha;
- same C-SAFE rule.

## Global decision surface

For every full-converged, indicator-available point define:

`E = alpha * Binf`.

Collect all distinct positive E values over the complete bank.

These values partition positive budget space into decision regions:
- below the smallest E;
- between every adjacent pair of distinct E values;
- above the largest E.

Use one representative budget per region:
- half the smallest E;
- geometric mean for finite interior intervals;
- twice the largest E.

For each representative budget apply C-SAFE independently to every physical
sequence.

Record:
- accepted sequence count;
- exhausted sequence count;
- accepted dt distribution;
- paired accepted count;
- realized paired H_INF maximum, median and 95th percentile;
- conservative margin minimum where paired;
- total retry index to acceptance.

## Identifiability criterion

A unique physical budget is identifiable from numerical evidence only if the
repository supplies an independent physical loss/accuracy criterion that
selects one decision region over the others.

Numerical changes in acceptance rate, retry count or realized error alone are
descriptive tradeoffs and do not constitute such a criterion.

## Gates

A1. Parent replay profile selection is exact.

A2. O0/O2 semantic identity.

A3. Every decision region is enumerated exactly once.

A4. C-SAFE semantics match ELASTIC57.

A5. Frozen global envelope remains satisfied for all paired accepted points.

A6. No alpha refit.

A7. Zero production `src/**` changes.

## Decision

ELASTIC58 may qualify:
- a unique budget if an already-authoritative independent physical criterion
  exists and selects exactly one region;
- otherwise a qualified non-identifiability/governance blocker with the full
  numerical decision surface preserved.

No production tolerance is admitted by this workunit.
