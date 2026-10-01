# F-MACRO-ALT36 — RFM shadow-runner contract

Date: 2026-10-01

Status: SOURCE-LEVEL_SHADOW_RUNNER_PERSISTED / REFERENCE_EXECUTION_OPTIONAL / PRODUCTION_UNCHANGED

## Purpose

Provide a sidecar research runner that evaluates frozen RFM-RC1 from the same accepted hydraulic state and forcing used by SWAP5 while publishing no production state or mass receipts.

## Contract

The runner consumes:

    accepted process_hydraulic_view_t
    existing constitutive_hydraulics_provider_t
    frozen RFM parameter DTO
    source rate and event age

and produces RFM diagnostic activation.

An optional reference receipt can be supplied by an existing/reference macropore route:

    preferential rate
    deep receipt rate
    mean deposition depth

When available, the sidecar reports deltas. When unavailable, RFM still runs and the comparison remains explicitly unavailable rather than inventing a legacy surrogate.

## Important current repository boundary

Canonical SWAP5 does not yet expose an admitted active production macropore execution route through the typed runtime. Therefore ALT36 does not pretend to execute a canonical legacy macropore model that is not present.

The runner is deliberately ready to accept such a receipt later from:

- the separately governed production macropore migration;
- a qualified legacy/reference executable;
- a source-bound comparison harness.

## Safety/ownership

The shadow runner:

- mutates no accepted state;
- commits no candidate state;
- publishes no production mass ledger;
- owns no restart state;
- does not enable macropore_active;
- does not alter surface-boundary ownership.

It is therefore suitable for paired diagnostics before production admission.

## Decision

RFM_SHADOW_SIDECAR = READY
PRODUCTION_MACROPORE_ROUTE = NOT CLAIMED
REFERENCE_COMPARISON = OPTIONAL_TYPED_RECEIPT
CANONICAL_PHYSICS_MUTATION = NONE

## Next use

When a qualified reference macropore receipt becomes available, run the same state/forcing through both routes and persist:

    activation difference
    deep receipt difference
    deposition-depth difference
    runtime/call-count difference
    state-memory footprint difference

without using either model to tune the other.
