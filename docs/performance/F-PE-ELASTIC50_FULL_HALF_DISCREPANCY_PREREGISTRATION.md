# F-PE-ELASTIC50 — full-versus-two-half state discrepancy characterization preregistration

Date: 2026-09-29

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
- F-PE-ELASTIC48 qualified solver-to-temporal limiter transition;
- F-PE-ELASTIC49 qualified Reference temporal identity gate.

Parent postimage:
`research/f-pe-elastic49-temporal-identity-policy@720cabe4b7c2d59bb06bdddb663f8c6d29cca2bc`

## Question

What are the actual physical state discrepancies between one full Reference
Richards solve and two sequential half solves on the retry ladder that the
current identity-only temporal gate rejects?

## Frozen cases

Use the same real profile, generated prior, 16-node variable grid, hydraulic
fixture, bottom mode 7, explicit-flux top boundary and numerical tolerances as
ELASTIC46-48.

States:
- h0 = 2 cm;
- h0 = 10 cm.

Perturbations:
- delta = +0.05 cm/day;
- delta = -0.05 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Retry ladder:
- start dt = 0.015625 day;
- retry scale = 0.5;
- indices 0 through 8.

Total direct comparison points:
`2 × 2 × 3 × 9 = 108`.

## Direct-solve construction

Bypass the identity-only transaction gate for measurement only.

Use the admitted `reference_richards_legacy_solver_t` directly with the same
soil-water request contract used by the serialized Reference backend.

For every comparison point:
1. construct one full-step request from the frozen initial state;
2. construct half1 from the same initial state with dt/2;
3. if half1 converges, construct half2 from half1 candidate state with dt/2;
4. preserve identical forcing and numerical settings;
5. do not commit any result to production state.

## Observations

Record:
- full solve status;
- half1 solve status;
- half2 solve status;
- solver diagnostics for all three;
- if all three converge:
  - max absolute pressure-head difference;
  - node index of max pressure-head difference;
  - max absolute water-content difference;
  - node index of max water-content difference;
  - absolute ponding-depth difference;
  - absolute groundwater-level difference;
  - full and two-half storage checksums;
  - exact bit-identity flag.

## Hypotheses

H1. Temporal-rejected active-ELAS attempts have finite, nonzero full-versus-half
state discrepancies rather than catastrophic/nonfinite state divergence.

H2. The discrepancy decreases with retry dt even when bit identity is not
reached.

H3. Pressure head is the dominant discrepancy component for the strongly
saturated cases.

H4. GENERATED and FIXED_1E6 exhibit different discrepancy magnitude/decay.

## Gates

A1. All 108 direct comparison points execute.
A2. No hidden change to forcing, boundary mode, solver or tolerances.
A3. Any reported discrepancy is emitted only when full, half1 and half2 all
converge.
A4. All reported discrepancy values are finite and nonnegative.
A5. O0/O2 classifications and discrepancy values are identical.
A6. Zero `src/**` production changes.

## Decision

ELASTIC50 is observational only.

A positive result may justify a separate temporal-metric design workunit.
No replacement metric, tolerance or timestep policy is admitted here.
