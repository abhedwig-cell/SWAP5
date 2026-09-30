# F-PE-ELASTIC59 — direct defect-head characterization result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-direct-defect-head`

Qualified postimage:
`6ac590996b2a61aa8ff2c99ac2180eda3eb0722e`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36698545344`

Job:
`109832254550`

Conclusion:
SUCCESS.

## Question

Is the excessive saturated conservatism of the mode-7 `Binf` indicator
primarily introduced by the final conversion

`Binf = bounded_M / sqrt(min_mass_weight)`?

## Research observables

ELASTIC59 reused the exact ELASTIC53 defect solve and exposed, research-only:

- `RAW_HEAD_INF = max(abs(e_raw))`;
- `DEFECT_HEAD_INF = max(abs(delta))`.

No extra nonlinear solve and no extra tridiagonal solve were added.

The production indicator and production result type were unchanged.

## Frozen bank

The exact four-profile ELASTIC55/58 bank was replayed:

- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- nine-step dt ladder;
- bottom mode 7;
- swkimpl=0.

Qualification:
- O0/O2 semantic identity: PASS;
- direct head observables finite/nonnegative whenever the indicator was
  available: PASS;
- no extra solve work: PASS;
- zero `src/**` production changes: PASS.

Paired full-versus-two-half observations:
- unsaturated: `537`;
- saturated: `264`;
- total: `801`.

## Primary result

The direct defect-head observable is dramatically tighter than `Binf` in the
saturated domain.

Across all 801 paired observations:

- `RAW_HEAD_INF < H_INF`: 0 cases;
- `DEFECT_HEAD_INF < H_INF`: 0 cases;
- `2*DEFECT_HEAD_INF < H_INF`: 0 cases.

Thus all three direct head-space observables remained conservative on the
characterization bank.

Most importantly, even

`DEFECT_HEAD_INF = max(abs(delta))`

alone remained above the realized full-versus-two-half `H_INF` in every paired
case.

This is a characterization result, not yet an independently held-out bound.

## Saturated domain

Across 264 paired saturated observations, the tightest observed ratios include:

`DEFECT_HEAD_INF / H_INF`
- minimum across profiles: approximately `3.75`;
- profile minima ranged approximately from `3.75` to `4.53`.

`2*DEFECT_HEAD_INF / H_INF`
- minimum across profiles: approximately `7.50`;
- profile minima ranged approximately from `7.50` to `9.06`.

By contrast, `Binf/H_INF` still reached several thousand on individual
saturated cases.

The amplification from the existing weighted-norm bound is directly visible in:

`Binf / (2*DEFECT_HEAD_INF)`.

Maximum observed saturated amplification:
approximately `110.04`.

Per-profile saturated maxima included:
- profile 11060: approximately `2.56`;
- profile 10260: approximately `75.99`;
- profile 8016: approximately `39.18`;
- profile 3030: approximately `110.04`.

Therefore the final minimum-mass-weight normalization can dominate the
conservatism by more than two orders of magnitude in the saturated bank.

## Unsaturated domain

The behavior is different when unsaturated.

Across 537 paired unsaturated observations, direct defect-head measures are
also conservative, but the existing Binf is not strongly amplified relative to
`2*DEFECT_HEAD_INF`.

Maximum observed:

`Binf/(2*DEFECT_HEAD_INF) < 0.956`.

This is consistent with the existing bounded-norm route often being controlled
by the raw branch in unsaturated cases.

The excessive Binf inflation is therefore specifically a saturated/small-mass-
weight effect rather than a universal property of the defect construction.

## Candidate comparison

### RAW_HEAD_INF

No underbound was observed.

Minimum saturated conservatism ratio:
approximately `3.89`.

This quantity is simple but represents the uncorrected raw temporal defect.

### DEFECT_HEAD_INF

No underbound was observed.

Minimum saturated conservatism ratio:
approximately `3.75`.

This is the tightest of the tested head-space candidates and directly uses the
already-computed defect-correction vector.

### 2*DEFECT_HEAD_INF

No underbound was observed.

Minimum saturated conservatism ratio:
approximately `7.50`.

It retains the factor 2 already present in the mass-weighted bounded-defect
construction, while avoiding the minimum-mass-weight infinity conversion.

## Hypothesis outcome

H1, saturated Binf conservatism is materially larger than direct defect-head
conservatism:
SUPPORTED.

H2, `2*DEFECT_HEAD_INF` remains conservative for most paired observations:
SUPPORTED more strongly than preregistered, with 0 failures over all 801 paired
observations.

H3, Binf amplification relative to direct defect head is largest in saturated
cases:
SUPPORTED.

Additional observation:
`DEFECT_HEAD_INF` itself also had 0 underbound cases in the characterization
bank.

## Interpretation

ELASTIC58 showed that deriving a Binf threshold from the independent
`0.01 cm` head limit was safe but unusably strict for every saturated
sequence.

ELASTIC59 identifies the mechanism.

The mode-7 defect solve itself is not producing an excessively large head-space
correction. The extreme saturated conservatism is introduced mainly when the
mass-weighted defect norm is converted to a global infinity bound using the
smallest mass weight.

This suggests a more direct trajectory-aware head indicator can preserve the
useful defect physics while avoiding the small-elastic-capacity amplification.

## Decision

Classification:

`QUALIFIED_DIRECT_DEFECT_HEAD_RESEARCH_CANDIDATE`.

No production admission is authorized.

Because the direct defect-head candidate was identified and assessed on the
same four-profile bank, the next bounded step must be a genuinely blind
multi-profile holdout.

That holdout should freeze before execution:
- candidate metric, preferably `DEFECT_HEAD_INF` and a conservative
  `2*DEFECT_HEAD_INF` comparator;
- the inherited physical head limit `0.01 cm`;
- profile selection distinct from ELASTIC55;
- no refitting or scaling.

Only if blind holdout preserves the physical head limit should saturated
C-SAFE practicality be evaluated.
