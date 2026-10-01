# PPA-WU05-A15 preregistration — bounded unponded RFM surface composition receipt

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@d89912713f9182f4a5319a54cb6094930d38e2cd

Prerequisites:

    PPA-WU05-A11 CLOSED_CANONICAL_ADMITTED
    PPA-WU05-A12 CLOSED_CANONICAL_ADMITTED
    PPA-WU05-A13 CLOSED_CANONICAL_ADMITTED
    PPA-WU05-A14 CLOSED_TRUE_OWNERSHIP_BLOCKER

## Purpose

Resolve the A14 ownership blocker only for the subset where the existing
Reference/B1.10 dynamic-top owner has already classified the interval as
unponded, runoff-free, flux-controlled.

The service creates an explicit common surface-composition receipt from:

    existing B1.10 surface preflight
      + already-qualified RFM activation partition

without using matrix actual_top_flux as the RFM source.

## Frozen authority rule

The B1.10 preflight is admissible only when all are true:

    status = SW_TOP_BOUNDARY_AVAILABLE
    regime = SW_TOP_BOUNDARY_REGIME_FLUX
    carries_surface_mass_terms = true
    runoff_resolved = true
    candidate_ponding_depth = 0 within tolerance
    runoff_depth = 0 within tolerance
    net_potential_surface_flux > 0

In this exact regime the B1.10 owner has already resolved surface evaporation
and has not entered ponding/head control.

A15 defines:

    effective_supply = net_potential_surface_flux

and requires the already-qualified A11 activation receipt to satisfy:

    effective_supply = matrix_rate + preferential_rate

within explicit tolerance.

## Why this is not circular

A15 does not use:

    actual_top_flux

as activation source.

The preflight is used only for:

- the existing evaporation-owned net surface supply;
- proof that the matrix-only Reference case is still unponded/runoff-free.

If the Reference preflight is head-controlled, ponded or runoff-active, A15
fails closed to REFERENCE_REQUIRED.

## Monotonic safety argument

For an interval already unponded under the matrix-only Reference boundary,
partitioning a nonnegative fraction of the same net supply into an additional
preferential intake path reduces the matrix supply.

Therefore this bounded slice cannot create a new matrix ponding exceedance from
a case that was already unponded before partition.

This claim does not authorize recovery of cases where preferential capacity
might prevent ponding. Those remain Reference-owned.

## Hard boundaries

A15 SHALL NOT:

- reinterpret actual_top_flux as RFM source;
- operate in any head-controlled regime;
- operate with positive candidate ponding or runoff;
- define evaporation, runoff or ponding laws;
- infer sigma_B;
- mutate solver or committed state;
- change A8/A9/A10 runtime;
- route preferential water.

## Qualification gates

1. synthetic unponded preflight with net supply 8 cm/day and a closing
   activation receipt 5.961748798503473 + 2.038251201496527 = 8 must pass;

2. exact receipt closure at <= 1e-12 cm/day;

3. nonzero runoff must return REFERENCE_REQUIRED;

4. positive ponding must return REFERENCE_REQUIRED;

5. head regime must return REFERENCE_REQUIRED;

6. unavailable/non-mass-carrying preflight must fail closed;

7. activation mismatch against net supply must fail closed;

8. actual_top_flux may differ in sign/value and is ignored for supply ownership.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_UNPONDED_SURFACE_COMPOSITION_RECEIPT
    EFFECTIVE_SUPPLY_RECEIPT_FALSIFIED
    BOUNDARY_FAIL_CLOSED_FALSIFIED
    TRUE_BLOCKER
