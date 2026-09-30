# F-PE-ELASTIC59 — direct head-space defect candidate preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_SAFE_UNSATURATED_HEAD_BUDGET_WITH_SATURATED_EXHAUSTION`

Parent postimage:
`research/f-pe-elastic58-physical-head-budget@56f1af0d5c24e624b0ced84c78f64b598f0850ef`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Can the excessive saturated conservatism of the mode-7 Binf conversion be
reduced without fitting a new scale, by expressing the same temporal defect
directly in pressure-head space?

## Existing indicator

The research mode-7 indicator computes:
- raw temporal defect vector `e_raw`;
- tridiagonal defect correction `delta`;
- mass-weighted raw and defect norms;
- `bounded_m = min(raw_m, 2*defect_m)`;
- `Binf = bounded_m / sqrt(min_mass_weight)`.

ELASTIC58 showed that the last conversion is safe but causes all saturated
sequences to exhaust under the inherited 0.01-cm head limit.

## Candidate

Define, without fitted coefficients:

`RAW_HINF = max_i |e_raw(i)|`

`DEFECT_HINF = max_i |delta(i)|`

`HCAND = min(RAW_HINF, 2*DEFECT_HINF)`

This mirrors the existing raw-versus-defect construction directly in head
space.

No alpha is fitted.

No empirical multiplier is introduced.

## Frozen bank

Reuse the complete ELASTIC55 multi-profile bank:
- profiles 11060, 10260, 8016, 3030;
- same retention/geometric/generated-Ss materialization;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- bottom mode 7;
- swkimpl=0.

## Primary falsification

For every paired-converged point test whether:

`H_INF <= HCAND`.

Any failure falsifies HCAND as a conservative realized full-vs-two-half
head-discrepancy bound on this bank.

## Secondary physical-budget test

Using the inherited independent head limit:

`H_limit = 0.01 cm`

apply C-SAFE directly to HCAND:

- full solve/indicator unavailable -> refine;
- `HCAND <= 0.01 cm` -> select;
- otherwise refine;
- if no point passes -> EXHAUSTED.

For every paired selected point require:
- `H_INF <= 0.01 cm`;
- `THETA_INF <= 1e-5`.

## Diagnostics

Report:
- HCAND/H_INF ratio range;
- Binf/H_INF ratio range for the same paired points;
- selected/exhausted counts under HCAND<=0.01;
- saturated selected count;
- unsaturated selected count;
- monotonicity violations for HCAND under dt refinement;
- comparison with Binf monotonicity on the same sequences.

## Gates

A1. Same four profiles and requested case bank.

A2. O0/O2 semantic identity.

A3. RAW_HINF, DEFECT_HINF and HCAND finite/nonnegative whenever available.

A4. No paired point violates `H_INF <= HCAND`.

A5. Every paired HCAND-selected point respects the inherited head and theta
limits.

A6. No fitted scaling or post-hoc multiplier.

A7. Zero `src/**` production changes.

## Decision

A green result qualifies only a research head-space defect candidate.

It does not authorize production replacement of Binf or a production temporal
budget.
