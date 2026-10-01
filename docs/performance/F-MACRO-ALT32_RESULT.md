# F-MACRO-ALT32 — provider-bound surface sorptivity and closed hydraulic input chain

Date: 2026-10-01

Status: QUALIFIED_SOURCE-LEVEL_RESEARCH_INTERFACE / HYDRAULIC_INPUT_CHAIN_CLOSED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Remove the last externally supplied hydraulic quantity from the source-level RFM research adapter.

ALT31 still required S_surface to be supplied as a number. ALT32 adds a provider-bound constitutive helper and a convenience adapter route that derives both K_surface and S_surface from accepted SWAP5 state plus the existing constitutive provider.

## New helper

tools/research/fortran/mod_rfm_surface_sorptivity.f90

The helper evaluates the transformed Parlange identity:

    S_surface^2 = integral_h_i^0
                    (theta_s + theta(h) - 2 theta_i) K(h) dh

with midpoint quadrature.

For every quadrature point it calls the existing constitutive provider using the combined water-content + conductivity demand mask.

It therefore contains no MvG equation, no inverse theta function and no duplicated conductivity implementation.

## Adapter integration

The research adapter now exposes:

    rfm_build_surface_hydraulic_input_from_state(...)

which performs:

    accepted process_hydraulic_view
        -> provider-bound S_surface
        -> provider point K_surface
        -> rfm_surface_hydraulic_input_t

and the existing activation routine then evaluates the frozen RFM relation.

## Ownership

The helper is pure calculation support in the architectural sense: it owns no persistent event state, no transaction state, no restart data and no mass ledger.

Surface source-event age remains explicit RFM event state. Wall-event age remains separate.

## Scope and performance boundary

The first source-level implementation uses direct quadrature through the provider. This is intentionally simple and auditable, not optimized.

If profiling later shows material cost, acceptable accelerations include adaptive quadrature, state-local caching or a constitutive lookup table, but only after numerical qualification against this direct provider-bound oracle.

## Qualification

A source-contract test is persisted as tools/research/macropore_alt32_provider_sorptivity_contract_test.py.

It verifies:

- the adapter imports and calls the new sorptivity helper;
- the helper depends on the abstract constitutive provider;
- the exact transformed-integrand form is present;
- no cofgen/default-MvG formula is duplicated in the helper;
- the adapter still obtains K_surface through evaluate_point_conductivity.

This is source-level qualification. The research modules are deliberately outside the production build and are not production-compiled/admitted by this workunit.

## Result

The RFM surface activation chain is now closed at the source-interface level:

    accepted SWAP5 top state
        -> constitutive theta/K
        -> S_surface
        -> K_surface
        -> b50(event age)
        -> preferential activation

No free b50, no characteristic time and no external hydraulic surrogate remain.

## Production boundary

Nothing in ALT32 changes canonical solver physics or production build manifests.

RFM remains a research alternative.

## Next

The next useful step is not another parameter or hydraulic formula. It is to execute this research interface against retained/default-MvG SWAP5 snapshots and quantify computational cost plus state-to-activation response. After that, a dedicated research runner can compose the existing ALT23 endpoint router with real SWAP5 hydraulic snapshots.
