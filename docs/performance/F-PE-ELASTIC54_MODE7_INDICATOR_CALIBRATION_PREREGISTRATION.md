# F-PE-ELASTIC54 — mode-7 defect-indicator calibration/falsification preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC53 — QUALIFIED_MODE7_DEFECT_INDICATOR_RESEARCH_CANDIDATE`

Parent branch head:
`research/f-pe-elastic53-mode7-defect-indicator@e6d3a18cd560faf9e810ad16af2f6d43b8696f5d`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Can the strongly conservative mode-7 defect indicator from ELASTIC53 be mapped
to a bounded, stable realized-error relation that survives explicit holdout
cases?

This is calibration/falsification only. It does not change production policy.

## Frozen model envelope

Preserve:
- profile 90116260;
- 16-node variable grid;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary;
- default-MvG hydraulics;
- OFF, FIXED_1E6 and GENERATED;
- same solver and tolerances as ELASTIC50-53.

## Calibration bank

Training states:
- h0 = -75, +2, +10 cm.

Training forcing perturbations:
- delta = +/-0.025 and +/-0.05 cm/day.

Holdout states:
- h0 = -20, +5 cm.

Holdout forcing perturbations:
- delta = +/-0.035 cm/day.

Retry ladder:
- dt0 = 0.015625 day;
- factor 0.5;
- retry indices 0 through 8.

Every case records:
- full solve status;
- mode-7 research Binf when full solve converges;
- full-versus-two-half H_INF when all three solves converge.

## Candidate calibration forms

Fit only on training paired-converged observations.

C1, global multiplicative scale:
`H_pred = alpha_global * Binf`

with
`alpha_global = max(H_INF/Binf)`
over training.

This is deliberately conservative in-sample.

C2, regime-specific multiplicative scale:
separate `alpha_OFF`, `alpha_FIXED`, `alpha_GENERATED`.

No intercept is allowed.

## Holdout falsification

For each holdout paired-converged observation test:
- `H_INF <= alpha_global * Binf`;
- where applicable, `H_INF <= alpha_regime * Binf`.

A candidate fails if any holdout exceeds its predicted conservative envelope.

Also characterize:
- monotonicity of Binf with decreasing dt;
- ratio spread;
- whether unsaturated controls behave qualitatively differently.

## Gates

A1. All training and holdout requested cases execute.

A2. O0/O2 semantic outputs agree.

A3. Binf is finite/nonnegative whenever the full solve converges.

A4. H_INF is emitted only when full, half1 and half2 converge.

A5. Training alphas are computed only from training observations.

A6. Holdout cases are never used to choose an alpha.

A7. Zero src/** production changes.

## Decision

ELASTIC54 may qualify:
- a falsified calibration route;
- or a research-only conservative scaling candidate.

It may not authorize:
- production acceptance thresholds;
- temporal policy replacement;
- default-on mode-7 defect control;
- solver or mass-gate relaxation.
