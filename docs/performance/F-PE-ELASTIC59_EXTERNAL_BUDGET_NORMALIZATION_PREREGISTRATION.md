# F-PE-ELASTIC59 — external physical head-budget normalization preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
- F-PE-ELASTIC58 — QUALIFIED_MODE7_MULTIMETRIC_ENDPOINT_ERROR_CHARACTERIZATION;
- F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN;
- F-CI21 / F-VQ32 — explicit supplied head-budget normalization, no default;
- canonical application-accuracy contract — application-owned, externally qualified head budgets.

Parent postimage:
`research/f-pe-elastic58-endpoint-error-bracketing@662a2c532be7d298ace02d157c89f2a45bc3be1a`

Canonical authority:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Frozen conservative scaling:
`alpha = 0.17320259355765216`.

## Question

Can an externally supplied physical temporal head-error budget be mapped
fail-closed onto the qualified mode-7 defect indicator without inventing a SWAP
default?

## Algebra

Qualified empirical relation from ELASTIC54/55:

`H_realized <= alpha * Binf`.

For an externally qualified physical temporal head budget `H_budget > 0`,
define

`C_phys = alpha * Binf / H_budget`.

Acceptance candidate:

`C_phys <= 1`.

Equivalent Binf-space budget:

`B_budget = H_budget / alpha`.

If the frozen conservative envelope remains valid, then any paired observation
with `C_phys <= 1` must also satisfy:

`H_realized <= H_budget`.

## Probe budgets

Qualification uses synthetic positive probes only:

- 0.01 cm;
- 0.1 cm;
- 1.0 cm.

These probe values exercise the algebra and are not application defaults,
recommendations or qualified tolerances.

Also test invalid budgets:
- zero;
- negative;
- +Inf;
- NaN.

Invalid or unavailable inputs must fail closed.

## Bank

Replay exactly the ELASTIC58 four-profile bank and paired endpoint observations.

For each valid probe:
- classify each full-converged indicator point by `C_phys <= 1`;
- where paired endpoint error exists, verify no false acceptance:
  `H_INF <= H_budget`;
- run C-SAFE logic with the normalized criterion.

## Gates

A1. Exact profile/case replay.
A2. O0/O2 semantic identity.
A3. Algebraic identity between `C_phys <= 1` and
    `Binf <= H_budget/alpha`.
A4. No paired false acceptance for any valid probe.
A5. Invalid budget or invalid indicator fails closed.
A6. Frozen alpha is bit/exactly unchanged and no refit occurs.
A7. No default budget is introduced.
A8. Zero src/** production changes.

## Decision

A green result qualifies only a research normalization bridge from an
externally supplied physical head-error budget to the conservative mode-7
indicator.

It does not qualify any numeric application budget or production binding.
