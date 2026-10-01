# F-MACRO-ALT31 — source-level RFM research adapter

Date: 2026-10-01

Status: SOURCE_LEVEL_RESEARCH_ADAPTER_PERSISTED / PRODUCTION_NOT_ADMITTED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Make the frozen ALT30 RFM parameter contract executable against actual SWAP5 accepted hydraulic state without inserting alternative macropore physics into the production solver.

## Adapter boundary

The adapter lives under tools/research/fortran and is deliberately outside the production source tree.

It consumes the existing process_hydraulic_view_t and constitutive_hydraulics_provider_t. The top-node pressure head and water content therefore come from accepted SWAP5 state, and K_surface is obtained through the existing provider evaluate_point_conductivity interface.

S_surface is supplied through the ALT12 constitutive-helper contract. The adapter does not duplicate retention or conductivity equations.

## Surface ownership

If accepted ponding_depth is positive, the RFM unponded activation route returns SURFACE_BOUNDARY_REQUIRED and computes no alternative surface split. Runoff/ponding/head-controlled physics therefore remain owned by the existing surface-boundary layer.

## Frozen parameter DTO

The research DTO contains:

    sigma_b
    f_mb
    connectivity_p
    chi_wall

with chi_wall defaulting to 1. The exchange length ell_ex is deliberately absent because ALT29 moved it to derived structural geometry.

## Implemented math

Unponded activation uses the frozen contract:

    b50 = K_surface + S_surface/(2 sqrt(event_age))
    B ~ LogNormal(log b50, sigma_B)
    q_matrix = E[min(R,B)]
    q_pref = R - q_matrix

The one-shape connectivity helper implements:

    C(z) = 1 - x^p

between derived/observed Z_AH and Z_IC.

## What is intentionally not implemented

- no production macropore state mutation;
- no mass ledger publication;
- no endpoint router inside HeadCalc;
- no wall-exchange mutation;
- no new surface runoff law;
- no restart representation;
- no production option switch.

This keeps the research adapter incapable of silently changing canonical SWAP5 physics.

## Qualification

A standard-library static/analytic contract test is persisted as tools/research/macropore_alt31_adapter_contract_test.py. It verifies that the research Fortran source depends on the constitutive provider, fail-closes on ponding, contains the frozen b50 relation and one-shape connectivity law, and preserves monotone activation response in a representative analytic screen.

Compilation/runtime integration remains a separate qualification step because this workunit intentionally avoids modifying production build manifests.

## Decision

RFM_SOURCE_ADAPTER = PERSISTED_FOR_RESEARCH
PRODUCTION_PHYSICS_MUTATION = NONE
ACCEPTED_STATE_CONSUMPTION = VIA EXISTING HYDRAULIC VIEW
K_SURFACE = VIA EXISTING CONSTITUTIVE PROVIDER
S_SURFACE = VIA FROZEN ALT12 HELPER CONTRACT
PONDING = FAIL_CLOSED TO SURFACE BOUNDARY OWNER

## Next

ALT32 should bind a typed/default-MvG surface-sorptivity provider to this adapter and run it on retained SWAP5 hydraulic snapshots/cases. That will remove the last externally supplied hydraulic quantity from the research adapter without changing the frozen RFM parameter contract.
