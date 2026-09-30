# F-PE-ELASTIC54 — mode-7 defect-indicator calibration/falsification result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic54-mode7-indicator-calibration`

Qualified postimage:
`2e994cb74a858b6316f851f4b3fc11cf613e7cca`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36672877932`

Job:
`109751496741`

Conclusion:
SUCCESS.

## Question

Can the ELASTIC53 mode-7 defect indicator be converted into a bounded
conservative realized-error relation that survives explicit holdout cases?

## Frozen bank

The research-only mode-7, swkimpl=0 defect indicator was evaluated on:

Training:
- h0 = -75, +2, +10 cm;
- delta = +/-0.025 and +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- 9-step retry ladder.

Holdout:
- h0 = -20 and +5 cm;
- delta = +/-0.035 cm/day;
- same three regimes;
- same retry ladder.

Total requested cases:
`432`.

Results:
- all 432 executed;
- 115 paired-converged training observations;
- 46 paired-converged holdout observations;
- 41 full-converged sequences with at least three indicator points;
- zero Binf monotonicity violations;
- O0/O2 semantic identity;
- zero src/** production changes.

## Training calibration

For each paired-converged training observation define:

`r = H_INF / Binf`.

The preregistered conservative multiplicative envelopes were:

Global:
`alpha_global = max(r) = 0.17320259355765216`.

Regime-specific:
- OFF: `0.17320259355765216`;
- FIXED_1E6: `0.030078656926636846`;
- GENERATED: `0.05628685829991343`.

The research prediction is:

`H_bound = alpha * Binf`.

No intercept was fitted.

## Blind holdout result

Global envelope:

`H_INF <= alpha_global * Binf`

passed all paired-converged holdout observations:

`0 / 46` holdout failures.

Therefore the global multiplicative envelope survives the preregistered
state/forcing holdout bank.

The tighter regime-specific envelope did not fully survive holdout:

`2 / 46` failures.

Both failures are FIXED_1E6, unsaturated holdout state `h0=-20 cm`,
at the largest tested interval `dt=0.015625 day`:

1. delta = -0.035 cm/day
   - observed H_INF = `0.00112561645 cm`;
   - Binf = `0.0285067228 cm`.

2. delta = +0.035 cm/day
   - observed H_INF = `0.00112959733 cm`;
   - Binf = `0.0285086207 cm`.

These imply holdout ratios of approximately `0.0395`, exceeding the training
FIXED_1E6 alpha `0.03008`.

The global envelope remains conservative for both cases.

## Monotonicity

Across 41 eligible full-converged sequences:

- monotonic Binf violations under decreasing dt: `0`.

This is a major contrast with the simple full-versus-two-half endpoint norms
from ELASTIC50/51, which were non-monotone under active ELAS.

The defect indicator therefore continues to behave structurally like a useful
timestep-control signal across the expanded bank.

## Interpretation

The strongest result is not the exact value of `alpha_global`.

The important result is that one training-derived global conservative scaling
survived all blind holdout observations in this bank while preserving monotonic
indicator behavior.

However, the failure of the tighter FIXED_1E6 regime-specific scaling shows
that:
- regime-specific calibration is not yet robust;
- the ratio depends on state domain as well as ELAS regime;
- unsaturated holdout behavior can exceed saturated/training-derived
  regime-specific envelopes.

Therefore the current evidence supports only a broad research envelope, not a
production threshold.

## Hypothesis assessment

Global multiplicative conservative scaling survives holdout:
SUPPORTED for this bank.

Regime-specific scaling survives holdout:
FALSIFIED for FIXED_1E6.

Binf remains monotone under retry refinement:
SUPPORTED, 0 violations across 41 eligible sequences.

Indicator remains available whenever the full solve converges:
SUPPORTED in the qualified bank.

## Decision

Classification:
`QUALIFIED_GLOBAL_MODE7_DEFECT_SCALING_RESEARCH_CANDIDATE`.

No production admission is authorized.

The next bounded workunit should test the global envelope on independent soil
profiles/materials and a wider unsaturated-to-saturated state domain.

Production admission should not be considered until:
- multi-profile holdout passes;
- the global scaling remains conservative;
- mass remains a separate hard gate;
- the one-extra-tridiagonal cost is measured end-to-end;
- transaction-policy integration is qualified independently.
