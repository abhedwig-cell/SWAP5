# F-PE-ELASTIC59 — refined-oracle mode-7 budget calibration preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_SAFE_BUT_OVERCONSERVATIVE_EXTERNAL_BUDGET_TRANSFER`

Parent postimage:
`research/f-pe-elastic58-external-budget-transfer@c0d83dca66a1a87547707a3d6b2ff5e6ea1b80be`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Purpose

Calibrate a mode-7-specific controller threshold against an independent refined
physical oracle, while keeping the physical head-error target external and
frozen.

## Frozen physical target

Independent TEMPORAL05 blind-holdout authority:

`H_TARGET = 0.0065653 cm`.

This target is not fitted from ELASTIC data.

## Profiles and split

Use the ELASTIC55 deterministic profile bank:

Training profiles:
- 11060;
- 10260;
- 8016.

Blind profile holdout:
- 3030.

No selected profile may move between training and holdout after results.

## Physical cases

For every profile:

States:
- h0 = -75, -20, +2, +10 cm.

Perturbations:
- delta = -0.05, -0.035, +0.035, +0.05 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Trial interval sizes:
- 0.015625 day;
- 0.0078125 day.

Total:
- training: 3 * 4 * 4 * 3 * 2 = 288 requested cases;
- holdout: 1 * 4 * 4 * 3 * 2 = 96 requested cases.

## Refined oracle

For each requested trial interval T:

1. compute the ordinary one-step full solution;
2. independently integrate the same T with 8 equal substeps;
3. independently integrate the same T with 16 equal substeps.

All paths begin from the exact same initial state and use identical forcing,
physics, bottom mode 7, swkimpl=0 and numerical tolerances.

A point is oracle-qualified only when:
- full, 8-substep and 16-substep paths all complete;
- every substep solve converges;
- all endpoint states are finite.

Define:

`H_REAL = max_i |h_full(i) - h_16(i)|`.

Define oracle self-consistency:

`H_ORACLE = max_i |h_8(i) - h_16(i)|`.

Require:

`H_ORACLE <= 0.1 * H_TARGET`

for a point to enter calibration or holdout decisions.

This criterion is frozen before execution.

## Indicator quantity

Use the already qualified research mode-7 indicator on the full trial:

`E_BOUND = alpha * Binf`

with frozen:

`alpha = 0.17320259355765216`.

No alpha refit is allowed.

## Training calibration

For oracle-qualified training points define unsafe physical points by:

`H_REAL > H_TARGET`.

Calibrate one scalar controller threshold `T_BOUND` only from training:

- if one or more unsafe points exist:
  `T_BOUND = min(E_BOUND over unsafe training points) * (1 - 1e-12)`;
- otherwise:
  `T_BOUND = max(E_BOUND over oracle-qualified training points)`.

This construction guarantees no observed unsafe training point is accepted by:

`E_BOUND <= T_BOUND`.

No holdout value may alter `T_BOUND`.

## Blind holdout test

For every oracle-qualified holdout point:

Accepted if:
`E_BOUND <= T_BOUND`.

Required:
- every accepted holdout has `H_REAL <= H_TARGET`;
- report false-reject fraction among physically safe holdout points;
- report acceptance fraction;
- report by regime/state class.

Any accepted holdout with `H_REAL > H_TARGET` falsifies the threshold.

## Secondary checks

Report:
- oracle-qualified count;
- oracle self-consistency distribution;
- full versus refined error distribution;
- training safe/unsafe counts;
- holdout safe/unsafe counts;
- threshold value;
- accepted holdout count;
- false accepts;
- false rejects.

## Gates

A1. Frozen profile split reproduced exactly.

A2. O0/O2 semantic identity for full/refined endpoints and Binf.

A3. Refined oracle uses only the requested forcing and admitted solver path.

A4. Oracle-qualified points satisfy the 8-vs-16 self-consistency criterion.

A5. T_BOUND is computed only from training profiles.

A6. Holdout profile 3030 is not used in calibration.

A7. Any accepted holdout is physically safe against H_TARGET.

A8. Hard mass acceptance is not relaxed.

A9. Zero `src/**` production changes.

## Decision

A positive result may qualify a mode-7-specific physical budget research
candidate.

It does not authorize production admission or a canonical F-CI14 numeric
profile.
