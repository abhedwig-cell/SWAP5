# PPA-WU05-A16 preregistration — bounded RFM matrix-share dynamic-top rebinding

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@ecfe628daf78988aec3a784f1b91b9d110d95850

Prerequisite:

    PPA-WU05-A15 CLOSED_CANONICAL_ADMITTED

## Purpose

Take the canonically admitted A15 matrix share and construct a fresh B1.10
dynamic-top request for the matrix route without double-counting atmospheric
source or evaporation.

The recomposed matrix request is accepted only if the existing B1.10 owner
again classifies it as flux-controlled, unponded and runoff-free.

## Rebinding contract

Inputs:

    original B1.10 request
    A15 surface-composition receipt

Required original state:

    previous ponding <= tolerance
    candidate ponding <= tolerance

Rebound request:

    pressure/head/hydraulic/runoff configuration = preserved
    previous ponding = 0
    candidate ponding = 0

    precipitation = A15 matrix_supply
    irrigation = 0
    snowmelt = 0
    runon = 0

    bare-soil evaporation demand = 0
    pond evaporation demand = 0

Rationale:

A15 matrix_supply is already a partition of B1.10 net_potential_surface_flux,
so the upstream surface evaporation owner has already acted. Reapplying
evaporation would double count mass removal.

## Qualification rule after B1.10 re-evaluation

The rebound result must satisfy:

    status = B110_DYN_TOP_AVAILABLE
    regime = B110_DYN_TOP_REGIME_FLUX
    candidate ponding <= tolerance
    runoff <= tolerance
    net_potential_surface_flux = matrix_supply within tolerance

If any condition fails:

    REFERENCE_REQUIRED

No live solver request is mutated by A16.

## Hard boundaries

A16 SHALL NOT:

- use actual_top_flux as a source;
- operate if original previous ponding is positive;
- retain original rain/irrigation/melt/runon after rebinding;
- retain evaporation demand after A15 partition;
- authorize head-controlled or runoff-active RFM;
- mutate A8/A9/A10 runtime;
- route preferential water;
- commit any state.

## Qualification gates

1. real B1.10/default-MvG fixture: 8 cm/day unponded preflight;
2. A15 matrix share 5.961748798503473 cm/day;
3. rebound request preserves hydraulic and runoff controls;
4. rebound source fields contain matrix share exactly once;
5. evaporation terms are zero;
6. rebound B1.10 result remains flux-controlled, unponded, runoff-free;
7. rebound net potential surface flux equals matrix share;
8. positive original previous ponding fails closed;
9. a deliberately excessive matrix share producing head-control is
   REFERENCE_REQUIRED.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_MATRIX_SHARE_REBINDING
    MATRIX_SHARE_REBINDING_FALSIFIED
    DOUBLE_COUNTING_GUARD_FALSIFIED
    RECOMPOSED_BOUNDARY_FALSIFIED
    TRUE_BLOCKER
