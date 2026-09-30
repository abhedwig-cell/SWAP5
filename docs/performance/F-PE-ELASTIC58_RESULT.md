# F-PE-ELASTIC58 — external temporal head-budget transferability result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-external-budget-transfer`

Qualified postimage:
`66ab571ffd492472f5a23e13905ed888086fd026`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36699918069`

Job:
`109836685339`

Conclusion:
SUCCESS.

## Question

Can independently qualified temporal head-error scales from TEMPORAL05 be
transferred, without refit, to the conservative mode-7 defect-indicator envelope
and the C-SAFE controller pattern?

## External authority

Two TEMPORAL05 physical head-error levels were frozen before replay:

- STRICT: `3.369e-3 cm`, the calibration maximum terminal absolute head error;
- LOOSE: `6.5653e-3 cm`, the blind-holdout maximum terminal absolute head error.

They were treated only as external research benchmarks.

The TEMPORAL05 history formula itself was not transferred because the isolated
ELASTIC55-57 bank does not own a preceding accepted-state
`||h_dot_previous||` history.

## Frozen mode-7 composition

The replay preserved:

- profiles 11060, 10260, 8016, 3030;
- same profile geometry/material/generated-Ss preparation;
- bottom mode 7;
- swkimpl=0;
- same mode-7 research defect indicator;
- frozen global conservative scale
  `alpha = 0.17320259355765216`;
- C-SAFE refinement without monotonicity assumption.

For every available full solve:

`E_bound = alpha * Binf`.

C-SAFE accepts the first available dt satisfying:

`E_bound <= B_external`.

## Aggregate result

### STRICT benchmark: 0.003369 cm

- sequences: 192;
- accepted: 90;
- exhausted: 102;
- acceptance fraction: `46.875%`;
- paired accepted: 78;
- paired safe: 78;
- nonmonotone sequences: 15;
- nonmonotone accepted: 0;
- nonmonotone exhausted: 15.

Classification:

`SAFE_BUT_OVERCONSERVATIVE_IN_BANK`.

### LOOSE benchmark: 0.0065653 cm

- sequences: 192;
- accepted: 96;
- exhausted: 96;
- acceptance fraction: `50.0%`;
- paired accepted: 90;
- paired safe: 90;
- nonmonotone sequences: 15;
- nonmonotone accepted: 0;
- nonmonotone exhausted: 15.

Classification:

`SAFE_BUT_OVERCONSERVATIVE_IN_BANK`.

Neither benchmark reaches the preregistered 75% practicality threshold.

## Safety

Every paired accepted observation satisfied both:

`H_INF <= alpha * Binf`

and

`H_INF <= B_external`.

No unavailable point was accepted.

No alpha refit occurred.

No production source changed.

## Per-profile behavior

The broad pattern is stable across all four profiles.

LOOSE benchmark acceptance:
- profile 11060: 24 / 48;
- profile 10260: 24 / 48;
- profile 8016: 24 / 48;
- profile 3030: 24 / 48.

STRICT benchmark:
- 11060: 24 / 48;
- 10260: 24 / 48;
- 8016: 18 / 48;
- 3030: 24 / 48.

The stricter external scale therefore becomes materially restrictive for profile
8016.

## Nonmonotone domain

None of the 15 ELASTIC56 nonmonotone sequences is accepted under either external
benchmark.

This is safe but too conservative to establish useful controller behavior in the
very domain that motivated ELASTIC56/57.

## Interpretation

The TEMPORAL05 physical head-error scale transfers safely but not practically.

This matters for two reasons.

First, it shows the current frozen mode-7 conservative envelope is not
underestimating observed endpoint error when constrained to an independently
validated sub-centimeter physical head-error scale.

Second, direct transfer of the TEMPORAL05 scale would discard roughly half of
the available mode-7 sequences and all localized nonmonotone sequences.

Therefore the missing production authority cannot be solved simply by copying
the TEMPORAL05 head scale into F-CI14.

A mode-7-specific physical temporal budget requires independent calibration
against a refined physical oracle.

## Hypothesis outcome

External benchmark safety:
SUPPORTED for both frozen levels.

Practical transferability:
NOT SUPPORTED.

Nonmonotone-domain usability:
NOT SUPPORTED. All 15 sequences exhaust under both benchmarks.

Need for mode-7-specific independent calibration:
SUPPORTED.

## Decision

Classification:

`QUALIFIED_SAFE_BUT_OVERCONSERVATIVE_EXTERNAL_BUDGET_TRANSFER`.

No production admission is authorized.

The next bounded workunit should independently calibrate a mode-7 physical
temporal budget against a refined-oracle trajectory, with:
- training/holdout separation;
- the four-profile material bank;
- saturated and unsaturated states;
- OFF, FIXED_1E6 and GENERATED;
- hard mass acceptance kept separate;
- no use of Binf itself to define the physical target.

Only after that calibration should the C-SAFE + alpha*Binf composition be
evaluated for production candidacy.
