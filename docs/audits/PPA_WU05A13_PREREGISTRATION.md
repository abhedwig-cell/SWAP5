# PPA-WU05-A13 preregistration — RFM surface-event age service

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@ae4eede414692fb0071ea093050f5accd36dd48d

Prerequisites:

    PPA-WU05-A11 CLOSED_CANONICAL_ADMITTED
    PPA-WU05-A12 CLOSED_CANONICAL_ADMITTED

Research authority:

    F-MACRO-ALT23
    F-MACRO-ALT24

## Purpose

Promote the already qualified surface-event-age information role into a small,
transaction-safe production service without choosing the atmospheric source
owner or changing source partition ownership.

ALT24 identifies:

    tau_surface

as persistent RFM physical/history state.

ALT23 qualifies repeated-event semantics: a separated second input event
restarts surface-event age and restores the early-time sorptivity contribution.

## Candidate semantics

The caller supplies for one already segmented physical interval:

    accepted_age_day
    event_active
    step_duration_day

A13 returns:

    evaluation_age_day
    candidate_age_day

For an active interval:

    evaluation_age = accepted_age + 0.5 * dt
    candidate_age  = accepted_age + dt

For an inactive interval:

    evaluation_age = 0
    candidate_age  = 0

The midpoint age matches the standalone ALT23 integration convention.

## Ownership boundary

The caller owns:

- deciding whether source/event is active;
- splitting intervals when event activity changes;
- the physical meaning of the effective infiltrating source;
- commit/discard of candidate age.

A13 owns only deterministic age evolution for an interval with constant
event-active identity.

## Transaction invariant

A13 is pure candidate construction.

It never mutates accepted state.

Therefore a rejected trial can discard candidate age and re-evaluate any retry
from the same accepted age.

## Hard exclusions

A13 SHALL NOT:

- inspect rainfall, irrigation, melt or runoff directly;
- infer event-active from a flux threshold;
- define a dry-gap duration threshold;
- change A8/A9/A10 top-input ownership;
- persist itself into an existing state layout;
- route preferential water;
- choose sigma_B.

## Qualification gates

1. first active dt=0.1 d:
   
       accepted=0
       evaluation=0.05
       candidate=0.1

2. continuation:
   
       accepted=0.1
       evaluation=0.15
       candidate=0.2

3. inactive interval resets candidate/evaluation to zero;

4. a new active interval after accepted reset starts again at dt/2;

5. retry/replay from the same accepted age is bit-identical;

6. invalid negative age or nonpositive dt fails closed.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_SURFACE_EVENT_AGE
    EVENT_AGE_SEMANTICS_FALSIFIED
    TRANSACTION_REPLAY_FALSIFIED
    TRUE_BLOCKER
