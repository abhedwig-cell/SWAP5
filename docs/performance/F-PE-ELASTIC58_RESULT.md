# F-PE-ELASTIC58 — independent reference-error frontier result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-reference-error-frontier`

Qualified postimage:
`7d1c3ba0c803815b54381a0b47a4e1f94f2a94e8`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36682787937`

Job:
`109781745992`

Conclusion:
SUCCESS.

## Question

What independently realized endpoint head error corresponds to the conservative
research quantity

`E_bound = alpha * Binf`

with frozen

`alpha = 0.17320259355765216`?

ELASTIC58 does not choose a production temporal budget.

## Independent reference construction

For each candidate step:
- one candidate solve was executed at dt;
- an independent 8-substep trajectory was integrated to the same endpoint;
- an independent 16-substep trajectory was integrated to the same endpoint;
- every reference substep had to converge;
- the pair was admitted to the frontier only when

`max|h_ref16-h_ref8| <= max(1e-5 cm, 0.1 * max|h_candidate-h_ref16|)`.

Thus the realized error frontier is not the full-versus-two-half endpoint
difference used in ELASTIC49-57.

## Bank

Profiles:
- 11060;
- 10260;
- 8016;
- 3030.

States:
- h0 = -75, -20, +2, +10 cm.

Forcing:
- delta = -0.035, +0.035 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Candidate dt:
- 0.015625;
- 0.0078125;
- 0.00390625;
- 0.001953125 day.

Requested candidate cases:
`384`.

Qualification:
- all 384 candidate cases executed;
- 325 full candidate solves converged;
- 112 cases passed the independent ref8/ref16 stability criterion;
- O0/O2 candidate/reference semantics agreed;
- no `src/**` production change.

## Frozen global envelope

For every reference-qualified case the independent error satisfied

`H_REF <= alpha * Binf`.

Envelope failures:
`0 / 112`.

This strengthens ELASTIC54/55 because the conservative scaling now bounds an
independently refined endpoint reference, not only a full-versus-two-half
endpoint discrepancy.

## Reference-error frontier

Pre-registered `E_bound` bands produced the following aggregate frontier.

### E_bound <= 0.01 cm

- count: `66`;
- weighted per-profile median H_REF: approximately `4.78e-5 cm`;
- maximum H_REF: `3.134e-4 cm`;
- maximum `H_REF/E_bound`: `0.2706`.

### 0.01 < E_bound <= 0.05 cm

- count: `21`;
- weighted per-profile median H_REF: approximately `7.58e-3 cm`;
- maximum H_REF: `1.549e-2 cm`;
- maximum ratio: `0.3902`.

### 0.05 < E_bound <= 0.10 cm

- count: `12`;
- weighted per-profile median H_REF: approximately `4.38e-2 cm`;
- maximum H_REF: `8.057e-2 cm`;
- maximum ratio: `0.9266`.

### 0.10 < E_bound <= 0.25 cm

- count: `1`;
- H_REF: `2.640e-2 cm`;
- ratio: `0.1283`.

### 0.25 < E_bound <= 0.50 cm

- count: `5`;
- weighted per-profile median H_REF: approximately `1.48e-2 cm`;
- maximum H_REF: `1.761e-2 cm`;
- maximum ratio: `0.0578`.

### E_bound > 0.50 cm

- count: `7`;
- weighted per-profile median H_REF: approximately `8.86e-3 cm`;
- maximum H_REF: `1.252e-2 cm`;
- maximum ratio: `0.0242`.

The frontier is not strictly ordered by band because the bank mixes state,
material, regime and candidate dt. ELASTIC58 therefore does not interpret band
membership alone as a physical acceptance decision.

## Per-profile qualification counts

Profile 11060:
- full-converged: 75;
- reference-qualified: 29;
- envelope failures: 0.

Profile 10260:
- full-converged: 82;
- reference-qualified: 34;
- envelope failures: 0.

Profile 8016:
- full-converged: 84;
- reference-qualified: 21;
- envelope failures: 0.

Profile 3030:
- full-converged: 84;
- reference-qualified: 28;
- envelope failures: 0.

## Important interpretation

The most informative frontier region is the smallest E_bound band.

When the conservative predicted bound is at most `0.01 cm`, the worst
independently observed pressure-head endpoint error in this bank is only about

`3.1e-4 cm`.

That is substantially smaller than the bound itself.

However, ELASTIC58 does not promote `0.01 cm` to a production tolerance.

Why not:
- the bank contains hydraulic-only mode-7 cases;
- optional process state remains outside the F-CI14 qualified scope;
- the larger E_bound bands are sparsely and unevenly populated;
- no user/domain accuracy requirement has yet been mapped onto a numeric
  pressure-head budget.

## Hypotheses

Frozen global envelope remains conservative against independent ref16 error:
SUPPORTED, 0 / 112 failures.

Smaller E_bound implies smaller realized error in the low-bound frontier:
SUPPORTED descriptively, especially for E_bound <= 0.01 cm.

A numeric production budget can already be admitted:
NOT ESTABLISHED.

## Decision

Classification:

`QUALIFIED_INDEPENDENT_MODE7_REFERENCE_ERROR_FRONTIER`.

No production temporal budget is admitted.

The next bounded step should convert this frontier into an explicit budget
qualification criterion with independent accuracy requirements and holdout,
rather than selecting a value only because it performed well in this bank.

Any subsequent production admission must still preserve:
- hard mass acceptance;
- C-SAFE refinement semantics;
- mode-7 operator qualification;
- optional-process fail-closed behavior.
