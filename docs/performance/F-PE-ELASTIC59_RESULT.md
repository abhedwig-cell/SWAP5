# F-PE-ELASTIC59 — direct head-space defect candidate result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT_WITH_SATURATED_EXHAUSTION

Branch:
`research/f-pe-elastic59-headspace-defect`

Qualified postimage:
`dfadff3e1b1a80d2daf3f3a0ea6f75ffc07af57f`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36680435142`

Job:
`109774470403`

Conclusion:
SUCCESS.

## Question

Can the excessive saturated conservatism of the mode-7 mass-weighted
`Binf` conversion be reduced without fitted scaling by using the same defect
solve directly in pressure-head space?

## Candidate

For the same temporal defect operator:

`RAW_HINF = max |e_raw|`

`DEFECT_HINF = max |delta|`

`HCAND = min(RAW_HINF, 2*DEFECT_HINF)`.

No empirical multiplier, alpha or intercept is fitted.

## Bank

The complete ELASTIC55 four-profile bank was replayed:
- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- nine-step dt ladder;
- mode-7, swkimpl=0.

Aggregate:
- full-converged points: `1089`;
- paired full/two-half points: `801`;
- O0/O2 semantic identity: PASS;
- zero production source changes.

## Primary conservatism test

Across all 801 paired points:

`H_INF <= HCAND`

held without exception.

Bound failures:
`0 / 801`.

Therefore HCAND is a conservative realized full-versus-two-half head-discrepancy
candidate on this bank.

## Monotonicity

HCAND materially improves retry-ladder regularity.

Across 170 eligible sequences:
- HCAND monotonicity violations: `0`;
- Binf monotonicity violations on the same sequences: `15`.

Thus direct head-space defect construction removes the specific nonmonotonicity
caveat identified in ELASTIC55/56.

## Conservatism ratio

HCAND remains conservative relative to realized endpoint discrepancy.

Per-profile HCAND/H_INF ranges:

- profile 11060:
  - minimum about `7.50`;
  - maximum about `1.17e5`.

- profile 10260:
  - minimum about `6.51`;
  - maximum about `4.83e4`.

- profile 8016:
  - minimum about `3.89`;
  - maximum about `1.02e3`.

- profile 3030:
  - minimum about `4.63`;
  - maximum about `8.97e4`.

The corresponding Binf/H_INF minima are generally larger, confirming that
HCAND is less conservative in the lower-ratio part of the bank, but both
constructions can be extremely conservative on some cases.

## Independent 0.01-cm head-budget replay

The inherited physical head limit remains:

`0.01 cm`.

Using C-SAFE with direct rule

`HCAND <= 0.01 cm`

gave:

- selected sequences: `84 / 192`;
- EXHAUSTED: `108 / 192`;
- paired selected: `69`;
- paired head-limit failures: `0`;
- paired theta-limit failures: `0`.

## Saturated exhaustion

All selected sequences are unsaturated.

Aggregate:
- saturated selected: `0`;
- unsaturated selected: `84`.

Therefore HCAND does not solve the saturated practicality problem identified in
ELASTIC58.

In fact, the direct 0.01-cm HCAND rule selects fewer total sequences than the
scaled Binf rule from ELASTIC58:
- ELASTIC58 selected: 96;
- ELASTIC59 selected: 84.

This is compatible with HCAND being a different conservative bound rather than
a calibrated estimate of endpoint error.

## Per-profile selection

### profile 11060
- selected: 24;
- exhausted: 24;
- paired selected: 24;
- saturated selected: 0.

### profile 10260
- selected: 24;
- exhausted: 24;
- paired selected: 12;
- saturated selected: 0.

### profile 8016
- selected: 12;
- exhausted: 36;
- paired selected: 12;
- saturated selected: 0.

### profile 3030
- selected: 24;
- exhausted: 24;
- paired selected: 21;
- saturated selected: 0.

## Interpretation

ELASTIC59 separates two issues that were conflated before.

### Structural indicator behavior

HCAND is a stronger controller signal than Binf in one important respect:

- conservative on all observed paired points;
- zero monotonicity violations over the multi-profile bank;
- derived directly from the same defect solve;
- no fitted scaling.

### Practical saturated acceptance

HCAND remains too conservative, or the tested saturated trajectories remain too
inaccurate, to satisfy the inherited 0.01-cm head limit within the frozen dt
ladder.

ELASTIC59 alone cannot distinguish those two explanations.

## Hypothesis outcome

Direct head-space defect candidate is conservative:
SUPPORTED, 0/801 failures.

HCAND retry-ladder monotonicity:
SUPPORTED, 0/170 violations.

HCAND solves saturated budget exhaustion:
FALSIFIED.

No-fit construction:
SUPPORTED.

## Decision

Classification:

`QUALIFIED_CONSERVATIVE_MONOTONE_HEADSPACE_CANDIDATE_WITH_SATURATED_EXHAUSTION`.

No production admission is authorized.

The next bounded workunit should separate:

1. `ORACLE_INFEASIBLE` saturated sequences, where no paired point in the
   frozen ladder achieves `H_INF <= 0.01 cm`;

from

2. `BOUND_OVERCONSERVATIVE` sequences, where a paired point does achieve the
   inherited physical head limit but HCAND still rejects every available dt.

That attribution is required before any further indicator redesign or dt-ladder
extension.
