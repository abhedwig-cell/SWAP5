# PPA-WU05-A19 preregistration — minimal dedicated RFM physical state

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@8cada0ea691cd129c8645fca0a4bb6626ba73422

Authority:

    PPA-WU05-A18 DEDICATED_RFM_OPTIONAL_PHYSICAL_STATE_LAYOUT_REQUIRED
    PPA-WU05-A17 explicit-parameter preferential router
    PPA-WU05-A13 surface-event age service

## Purpose

Implement and qualify the minimal physical/history state required by the
currently admitted bounded RFM chain, without yet wiring it into the serialized
backend or assigning an optional-state layout ID.

## State roles

Mutable physical/history state:

    mb_water_cm
    endpoint_water_cm(:)
    tau_surface_day

Not state:

    endpoint depths
    Z_AH
    Z_IC
    f_MB
    p
    sigma_B
    K_surface
    S_surface

Those remain immutable configuration or derived hydraulic quantities.

## A17 unit ownership

A17 receives A15 surface rates in cm/day. Its outputs:

    mb_amount
    ic_amount
    endpoint_amount(:)

therefore retain the same rate unit despite the historical field name
"amount".

A19 is the unique owner of interval integration:

    input_cm = A17 routing rate * dt_day

No downstream state owner may multiply those A17 rates by dt a second time.

## Candidate construction

Inputs:

    accepted RFM state
    A17 routing result
    A13 event-age result
    dt_day

Candidate:

    candidate.mb_water
      = accepted.mb_water + routing.mb_amount * dt

    candidate.endpoint_water(:)
      = accepted.endpoint_water(:) + routing.endpoint_amount(:) * dt

    candidate.tau_surface
      = event_age.candidate_age_day

No output/exchange process is included in A19.

Receipt:

    preferential_input_cm
    mb_input_cm
    ic_input_cm
    storage_start_cm
    storage_end_cm
    storage_change_cm
    mass_residual_cm

with:

    storage_change = preferential_input

within tolerance.

## Transaction boundary

Candidate construction must not mutate accepted state.

Retry from the same accepted state and same receipts must be bit-identical.

Commit/restart/backend integration remains future scope.

## Qualification gates

1. initialization with N endpoint classes;
2. ready/valid state requires finite nonnegative storage and tau;
3. copy identity;
4. accepted-state immutability after candidate construction;
5. one-step candidate receipt closes to <= 1e-12 cm;
6. replay from same accepted state is bit-identical;
7. endpoint-size mismatch fails closed;
8. invalid routing/event-age status fails closed;
9. nonpositive dt fails closed.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_PHYSICAL_STATE
    STATE_COPY_FALSIFIED
    CANDIDATE_MASS_FALSIFIED
    RETRY_IMMUTABILITY_FALSIFIED
    TRUE_BLOCKER
