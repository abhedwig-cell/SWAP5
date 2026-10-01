# F-MACRO-ALT56 — audit of reusable matrix-solute transport ownership

Date: 2026-10-01

Status: MATRIX_SOLUTE_OWNER_NOT_AVAILABLE / COMPOSITION_BLOCKER_CONFIRMED / NO_TOY_TRANSPORT_AUTHORIZED

Canonical SWAP5 authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Resolve the only remaining implementation dependency exposed by ALT55:

> Is there already a qualified conservative matrix-solute/tracer transport owner in SWAP5 or ANIMO5 that can publish the retained matrix tracer profile required by the RFM conservative-tracer forward ledger?

The answer is:

    no current qualified reusable owner was found.

## SWAP5 audit

A recursive canonical SWAP5 inventory for:

    solute
    tracer
    transport
    bromide
    dispersion
    conservative

finds no generic matrix-solute transport process.

The only transport-named canonical hit is a solver trajectory-transport test, which concerns numerical state/directional publication rather than chemical solute mass.

Therefore canonical SWAP5 cannot currently supply:

    M_matrix_retained(z)

to ALT55.

## ANIMO5 architecture audit

Relevant active ANIMO5 branches were inspected rather than relying on the nearly empty default branch.

### ARCH03 mass ledger

`work/animo-arch03-mass-ledger-observer` defines an observer architecture with:

    R_Q = S_end - S_begin - I_external + O_external

and explicit typed transfer-event semantics.

Its own status is:

    CANDIDATE_ARCHITECTURE_DESIGN_NOT_CANONICAL_MASS_GATE.

The document explicitly says the ledger:

- observes rather than owns physical mass;
- does not mutate model state;
- does not choose timesteps;
- does not repair producer nonclosure.

This is compatible with ALT55 ownership principles, but it is not a solute transport producer.

### ARCH05 hydrology exchange

`work/animo-arch05-external-exchange-contracts` defines externally owned hydrology state plus interval-integrated water transfers.

The hydrology contract explicitly states:

    water quantity does not define chemical composition.

Irrigation/runon/deposition/bottom concentrations belong to separate chemistry/material contracts.

It also states that ARCH05 does not define SWAP mappings, numerical transport execution, or production ABI.

Again, this is the correct future coupling boundary but not a matrix-solute kernel.

## ANIMO KT06 / KT11 runtime audit

The later KT11 review branch was inspected:

    review/animo-kt11-multi-packet-hydrology-provider-independent

The frozen implementation is:

    prototype/kt11/mod_animo_multi_packet_hydrology_provider.f90

with a successful exact-head authoring CI run recorded in the review packet, but its independent review status is still:

    NOT_YET_QUALIFIED_UNDER_GOV04_TIER_C
    NOT_ADMITTED.

KT11 stores immutable hydrology packets keyed by producer interval and delegates one exact packet to KT06.

KT06:

    prototype/kt06/mod_animo_explicit_hydrology_runtime_binding.f90

validates and projects hydrology state/transfers.

Its test/probe accepted payload contains only:

    state_token

and candidate execution preserves that token.

Neither KT06 nor KT11:

- advects solute concentration;
- evaluates dispersion;
- transports conservative tracer mass;
- produces a retained solute profile by layer;
- publishes a chemical mass ledger.

Therefore:

    KT11_HYDROLOGY_PROVIDER != MATRIX_SOLUTE_TRANSPORT_OWNER.

## Why ANIMO contracts are still useful

The ANIMO5 architecture strongly corroborates the ownership decision made independently in ALT55:

- hydrology owns water state/transfers;
- chemistry composition is separate;
- physical transfers must be typed once;
- ledger observation must not fabricate balancing fluxes;
- rejected trials must not publish physical transfer mass.

So ANIMO5 validates the *architecture direction* of ALT55.

It does not yet supply the missing runtime process.

## Consequence for the bromide forward problem

The RFM research line currently has:

1. surface activation machinery;
2. MB/IC split;
3. held-out validated IC endpoint-mass law;
4. wall-exchange process semantics;
5. absolute applied/recovered bromide constraints;
6. an exact conservative tracer composition ledger.

But it does not have a qualified producer for:

    matrix retained tracer profile M_matrix(z,t_sample).

Without that producer, an absolute fit of f_MB would necessarily require introducing a new advection-dispersion/solute model.

Doing that inside RFM would:

- expand RFM physics beyond preferential-flow scope;
- add dispersivity / solute-transport parameters;
- confound f_MB with matrix transport;
- duplicate future ANIMO/SWAP solute ownership;
- weaken the interpretation of the bromide validation.

ALT56 therefore forbids this shortcut.

## Decision

    SWAP5_MATRIX_SOLUTE_OWNER = ABSENT
    ANIMO5_ARCH03_LEDGER = ARCHITECTURALLY_COMPATIBLE_BUT_OBSERVER_ONLY
    ANIMO5_ARCH05_HYDROLOGY = ARCHITECTURALLY_COMPATIBLE_BUT_WATER_ONLY
    ANIMO5_KT06_KT11 = HYDROLOGY_PACKET_BINDING_NOT_SOLUTE_TRANSPORT
    QUALIFIED_REUSABLE_MATRIX_TRACER_OWNER = NOT_AVAILABLE
    TOY_ADE_INSIDE_RFM = REJECTED
    ALT55_ABSOLUTE_FORWARD_FIT = BLOCKED_ON_EXTERNAL_MATRIX_SOLUTE_OWNER

## Resume condition

Resume the absolute bromide forward fit only when one of these exists:

1. a qualified SWAP5 conservative-solute transport owner;
2. an ANIMO5 transport runtime that consumes typed hydrology transfers and publishes conservative layer tracer mass;
3. another independently qualified matrix-tracer solver whose parameters are fixed outside the RFM calibration.

At that point connect it to ALT55 without changing the RFM parameter contract.

## Research-line implication

This is a genuine architecture/composition blocker, not an empirical-data blocker.

The empirical result for p remains valid because ALT51/52 use normalized observed conservative tracer depth mass directly and do not depend on a forward matrix-solute model.

The unresolved parameters remain:

    sigma_B magnitude
    f_MB

while:

    p

has the strongest current empirical qualification.
