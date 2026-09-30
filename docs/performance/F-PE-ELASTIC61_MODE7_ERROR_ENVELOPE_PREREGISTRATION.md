# F-PE-ELASTIC61 — mode-7 conservative head-error envelope admission preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent production authority:
- F-PE-ELASTIC59: mode-7 typed mass publication admitted;
- F-PE-ELASTIC60: mode-7, swkimpl=0 Richards defect indicator admitted.

Research authority inherited through ELASTIC60 closeout:
- ELASTIC54: qualified global conservative scaling candidate;
- ELASTIC55: 0/801 multi-profile envelope failures;
- ELASTIC56: localized Binf nonmonotonicity with envelope preserved;
- ELASTIC57: nonmonotonicity-robust refinement controller pattern.

Frozen research scaling:

`alpha = 0.17320259355765216`.

## Purpose

Admit only a typed production adapter that converts the already admitted
mode-7 Richards `head_inf_bound` into a conservative head-error estimate and
compares that estimate with an **explicit caller-owned head budget**.

The adapter does not choose a budget and does not own timestep refinement.

## Contract

Inputs:
- `head_inf_bound_cm`;
- `head_budget_cm`.

Frozen estimate:

`estimated_head_error_cm = alpha * head_inf_bound_cm`.

For a positive finite budget:

`normalized_error = estimated_head_error_cm / head_budget_cm`.

Acceptance:

`accepted = normalized_error <= 1`.

Zero-budget semantics:
- zero estimate + zero budget -> accepted, normalized error 0;
- positive estimate + zero budget -> rejected.

Invalid/nonfinite/negative input fails closed.

## No defaults

No numeric head budget is supplied by production code.

The caller must explicitly provide `head_budget_cm`.

This preserves F-CI14's rule that physical temporal limits are not silently
reused from solver convergence tolerances.

## Production scope

Expected source delta:
- one new stateless adapter module under `src/adapter/`.

No existing solver, HeadCalc, transaction, runtime, mass, retry, constitutive,
boundary, or canonical numerical-config source may change.

## Qualification

A1. Public alpha is bit-identical to
`0.17320259355765216_real64`.

A2. Finite positive inputs reproduce the exact frozen formula.

A3. Exact threshold behavior:
- estimate below budget -> accepted;
- estimate equal to budget -> accepted;
- estimate above budget -> rejected.

A4. Zero-budget exact-equality semantics.

A5. Negative/nonfinite bound or budget fails closed.

A6. Adapter is stateless and does not mutate solver/transaction state.

A7. Existing production mode-7 indicator and typed-mass seams replay unchanged.

A8. O0/O2 semantic identity.

A9. Exact production source scope is one new adapter module only.

## Admission boundary

A green ELASTIC61 admits only:

`mode7 Binf + frozen conservative alpha + explicit caller-owned head budget
 -> typed normalized head-error assessment`.

It does not admit:
- a default head budget;
- a complete F-CI14 eight-metric numeric profile;
- C-SAFE production controller binding;
- default-on temporal control;
- swkimpl=1;
- any mass-gate relaxation.
