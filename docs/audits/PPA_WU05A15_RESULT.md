# PPA-WU05-A15 result — bounded unponded RFM surface composition receipt

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@d89912713f9182f4a5319a54cb6094930d38e2cd

Qualified postimage:

    1056406db887aab0b3fe13d3a5071da5965275fa

Qualification run:

    36863638042 — SUCCESS

Focused gate output:

    PPA_WU05A15_RFM_UNPONDED_SURFACE_COMPOSITION=PASS

## Qualified scope

A15 resolves the A14 effective-supply ownership blocker only for intervals that
the existing B1.10 dynamic-top owner already classifies as:

    available
    flux-controlled
    unponded
    runoff-free
    carrying surface mass terms.

For that bounded subset:

    effective_supply = net_potential_surface_flux

and the A11 activation receipt must close:

    effective_supply = matrix_supply + preferential_supply.

The service does not use actual_top_flux as the RFM source.

## Qualification gates

Passed:

- synthetic 8 cm/day supply receipt;
- partition closure <= 1e-12 cm/day;
- actual_top_flux deliberately changed without changing ownership result;
- runoff -> REFERENCE_REQUIRED;
- ponding -> REFERENCE_REQUIRED;
- head regime -> REFERENCE_REQUIRED;
- unavailable/non-mass-carrying preflight -> INVALID;
- activation/supply mismatch -> INVALID.

## Interpretation

A14 is no longer a blocker for the strictly unponded flux subset.

It remains a blocker for ponded/head-controlled cases and for any attempt to
recover a matrix-only ponded case by adding preferential capacity.

A15 is a receipt/composition primitive. It does not yet mutate the live matrix
top-boundary request or route preferential water.

## Lifecycle

    implemented -> persisted -> tested -> qualified
