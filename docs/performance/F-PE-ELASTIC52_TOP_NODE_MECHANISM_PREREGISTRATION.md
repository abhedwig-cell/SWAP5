# F-PE-ELASTIC52 — active-ELAS top-node mechanism attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
- F-PE-ELASTIC50 qualified finite localized full-half discrepancy;
- F-PE-ELASTIC51 qualified negative simple temporal metric result.

Parent postimage:
`research/f-pe-elastic51-candidate-temporal-metrics@1e432bfe35beb03a7199beffe6552bc7a2a22057`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Why does the full-versus-two-half discrepancy at saturated node 1 increase
over the first retry halvings when ELAS is active?

## Frozen bank

Reuse the ELASTIC50 direct-solve bank exactly:
- profile 90116260;
- 16-node variable grid;
- bottom mode 7;
- explicit fixed-flux top boundary;
- h0 = 2 and 10 cm;
- delta = +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- start dt = 0.015625 day;
- retry scale = 0.5;
- retry indices 0 through 8.

No solver, forcing, boundary, constitutive or tolerance change.

## Top-node balance identity

For the admitted fixed-flux route with no node-local source/sink/root sink,
the converged node-1 residual is

`dz1 * (theta1_end-theta1_start)/dt + q12_term + qtop = 0`.

For each converged full, half1 and half2 solve define:

- `storage_rate_1 = dz1 * (theta1_end-theta1_start)/step_dt`;
- `internal_flux_term_1 = -qtop - storage_rate_1`.

These are direct state/boundary consequences of the production residual
equation, not a replacement solver.

## Observations

For every direct comparison point record, separately for full, half1 and half2:

- top-node pressure head;
- node-2 pressure head;
- top-node water content;
- top-node pressure-head increment from that substep's own start;
- top-node water-content increment;
- top-node storage rate;
- implied internal vertical flux term;
- nonlinear iterations and solve status.

When all three solves converge also record:

- full-vs-half2 pressure-head difference at node 1;
- difference between full-step and half2 terminal storage rates;
- difference between full-step and half2 implied internal flux terms;
- half1 and half2 pressure-head increments.

## Hypotheses

H1. The growing full/half discrepancy under active ELAS is associated with
different internal vertical-flux responses, not a difference in qtop or ponding.

H2. Because saturated elastic theta is linear in h, node-1 water-content and
storage-rate differences are proportional to pressure-head differences.

H3. The half2 solve starts from the half1 postimage and therefore samples a
different internal hydraulic-gradient trajectory than the full solve; this
trajectory split explains the non-monotone retry-ladder behavior.

H4. OFF and active-ELAS routes show qualitatively different top-node increment
patterns.

## Gates

A1. Same 108 comparison points execute.

A2. Derived balance terms are emitted only from finite states; comparison terms
only when full, half1 and half2 converge.

A3. qtop is identical across full, half1 and half2 by construction.

A4. For active ELAS, theta/h increment proportionality matches node-local Ss
within floating-point tolerance when all relevant states remain saturated.

A5. O0/O2 outputs agree exactly.

A6. No production source change.

## Decision

ELASTIC52 is attribution-only.

No temporal metric, tolerance, retry policy, boundary behavior or ELAS physics
is changed here.
