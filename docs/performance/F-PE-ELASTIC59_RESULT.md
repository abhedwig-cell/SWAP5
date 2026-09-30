# F-PE-ELASTIC59 — refined-oracle mode-7 budget calibration result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-refined-oracle-budget-calibration`

Qualified postimage:
`0389ae3fd417bf945d68fbe393617b6dd4ce615f`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36700834340`

Job:
`109839625474`

Conclusion:
SUCCESS.

## Question

Can a mode-7-specific temporal controller threshold be calibrated from an
independent refined physical oracle while keeping the physical target external
and the Binf scaling frozen?

## Frozen independent target

TEMPORAL05 blind-holdout physical head-error authority:

`H_TARGET = 0.0065653 cm`.

No ELASTIC result was used to choose that physical target.

Frozen mode-7 conservative scaling:

`E_BOUND = alpha * Binf`

with:

`alpha = 0.17320259355765216`.

No alpha refit occurred.

## Refined oracle

For every requested point:

- one full trial over T;
- one independent 8-substep integration over T;
- one independent 16-substep integration over T.

Oracle-realized full-step error:

`H_REAL = max |h_full - h_16|`.

Oracle self-consistency:

`H_ORACLE = max |h_8 - h_16|`.

Only points satisfying:

`H_ORACLE <= 0.1 * H_TARGET = 6.5653e-4 cm`

entered calibration/holdout decisions.

## Frozen split

Training profiles:
- 11060;
- 10260;
- 8016.

Blind holdout profile:
- 3030.

The holdout profile did not participate in threshold calibration.

Requested cases:
- training: 288;
- holdout: 96.

## Oracle qualification

Training:

### profile 11060
- oracle-qualified: 52;
- physically safe: 49;
- physically unsafe: 3.

### profile 10260
- oracle-qualified: 55;
- safe: 41;
- unsafe: 14.

### profile 8016
- oracle-qualified: 17;
- safe: 13;
- unsafe: 4.

Aggregate training:
- oracle-qualified: 124;
- safe: 103;
- unsafe: 21.

Holdout profile 3030:
- oracle-qualified: 34;
- safe: 31;
- unsafe: 3.

## Training-only threshold calibration

Unsafe means:

`H_REAL > H_TARGET`.

Because unsafe training points exist, the preregistered threshold is:

`T_BOUND = min(E_BOUND over unsafe training points) * (1 - 1e-12)`.

Result:

`T_BOUND = 0.049428424452890203 cm`.

Training outcome:
- accepted: 96 / 124 oracle-qualified points;
- unsafe accepted: 0.

The threshold is therefore conservative on the complete training bank by
construction, without using holdout values.

## Blind holdout result

Holdout oracle-qualified points:
`34`.

Physical classes:
- safe: 31;
- unsafe: 3.

Applying the frozen training-derived threshold:

`E_BOUND <= 0.049428424452890203 cm`

gives:

- accepted: 30 / 34;
- false accepts: 0;
- false rejects: 1;
- acceptance fraction: `88.2353%`;
- safe-reject fraction: `3.2258%`.

Blind holdout classification:

`PASS`.

## Single false reject

The only physically safe holdout point rejected by the calibrated bound is:

- profile 3030;
- regime FIXED_1E6;
- h0 = +10 cm;
- delta = -0.035 cm/day;
- dt = 0.015625 day.

Observed refined-oracle error:

`H_REAL = 0.00373021053 cm`.

Oracle self-difference:

`H_ORACLE = 2.1237e-8 cm`.

Conservative bound:

`E_BOUND = 1.67510449 cm`.

Thus the point is physically safe against the external target but strongly
overbounded by the mode-7 defect envelope.

This is inefficiency, not a safety failure.

## Safety result

No holdout point with:

`H_REAL > 0.0065653 cm`

was accepted.

Therefore the training-derived mode-7 threshold survives a blind independent
profile holdout with zero false accepts.

## Interpretation

ELASTIC58 showed that directly copying the TEMPORAL05 head-error scale onto
`alpha * Binf` was safe but too conservative, accepting only about half of
sequences.

ELASTIC59 separates the physical target from the indicator threshold.

The physical requirement remains:

`H_REAL <= 0.0065653 cm`.

The mode-7 controller threshold is instead calibrated against independent
refined-oracle evidence:

`alpha * Binf <= 0.04942842445 cm`.

This greatly improves practical acceptance while retaining zero false accepts
in the blind profile holdout.

The result also confirms that `E_BOUND` is a conservative classification
signal, not a point estimate of realized head error.

## Hypothesis outcome

Independent refined-oracle calibration:
SUPPORTED.

Training-only threshold derivation:
SUPPORTED.

Blind holdout safety:
SUPPORTED, 0 false accepts.

Holdout practicality:
SUPPORTED, 88.2% acceptance.

Perfect specificity:
NOT SUPPORTED, one safe holdout false reject.

Production readiness:
NOT YET ESTABLISHED.

## Decision

Classification:

`QUALIFIED_MODE7_REFINED_ORACLE_TEMPORAL_BUDGET_RESEARCH_CANDIDATE`.

No production admission is authorized.

The next bounded step should qualify the complete transaction-level
composition:

- mode-7 defect indicator;
- frozen alpha;
- calibrated `T_BOUND`;
- C-SAFE refinement;
- hard mass acceptance;
- rollback/commit semantics;
- accepted-state identity;
- comparison against the current Reference transaction path.

That integration must remain research-only until end-to-end correctness,
performance and preservation gates pass.
