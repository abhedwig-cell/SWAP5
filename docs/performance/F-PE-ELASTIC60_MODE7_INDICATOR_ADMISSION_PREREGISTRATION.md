# F-PE-ELASTIC60 — production admission candidate for mode-7 Richards defect indicator

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Research authority:
- F-PE-ELASTIC53: QUALIFIED_MODE7_DEFECT_INDICATOR_RESEARCH_CANDIDATE;
- F-PE-ELASTIC54: QUALIFIED_GLOBAL_MODE7_DEFECT_SCALING_RESEARCH_CANDIDATE;
- F-PE-ELASTIC55: multi-profile global envelope holdout PASS;
- F-PE-ELASTIC56: localized nonmonotonicity with global envelope preserved;
- F-PE-ELASTIC57: nonmonotonicity-robust controller pattern;
- F-PE-ELASTIC58: multi-metric endpoint characterization;
- F-PE-ELASTIC59: external physical-budget normalization.

## Purpose

Admit only the production **availability** of the existing Reference Richards
defect temporal indicator for bottom mode 7 within the already qualified
numerical envelope.

This workunit does not admit a temporal budget or controller.

## Exact production delta

Modify only:

`src/solver/mod_reference_richards_temporal_indicator.f90`

Boundary envelope changes from:

`bottom_mode in {2,5}`

to:

`bottom_mode in {2,5,7}`.

No other operator term is changed.

The existing mode-5 Dirichlet bottom stiffness remains mode-5-only.

## Qualified mode-7 envelope

Mode 7 is available only when all pre-existing indicator gates also pass,
including:

- `swkimpl=0` / conductivity_implicit_mode = 0;
- conductivity mean method = 1;
- fixed-flux top boundary;
- no macropore-active envelope;
- admitted constitutive/provider types;
- converged candidate;
- valid previous right derivative.

Thus mode 7 with `swkimpl=1` remains fail-closed without any new special case.

## Qualification

A1. Exact source scope: only the one production indicator module changes.

A2. Independent mode-7 oracle:
- uniform unsaturated free-drainage equilibrium;
- qtop = -K + signed perturbation;
- bottom mode 7;
- swkimpl=0;
- independent zero-bottom-stiffness tridiagonal operator;
- production indicator reproduces raw, defect, bounded and Binf outputs.

A3. Stationary free-drainage case produces zero temporal indicator.

A4. Production solver binding returns AVAILABLE for qualified mode 7.

A5. swkimpl=1 mode 7 remains UNAVAILABLE through the existing conductivity-policy gate.

A6. Existing F-SI38 mode-2 and mode-5 qualification replay remains green.

A7. O0/O2 semantic identity.

A8. No temporal budget/default/controller is added.

## Admission boundary

A green ELASTIC60 qualifies only:

`bottom_mode=7 + swkimpl=0 -> production Reference Richards defect indicator available`.

It does not qualify:
- a numeric H_budget;
- alpha normalization in production;
- C-SAFE production controller binding;
- default-on temporal control;
- swkimpl=1;
- optional active-process compositions outside the existing indicator envelope.
