# F-PE-TIMEARCH02 result — executable timestep decision contracts

Date: 2026-09-28

Status: `QUALIFIED_EXECUTABLE_TIMESTEP_DECISION_CONTRACTS`

Base authority at preregistration:

`integration/f-ci-canonical@79dde9d93fe17dd686ba9902eca2bd0ab0d2f26b`

Current canonical during closeout:

`integration/f-ci-canonical@bf5c223557a2ac4ce2446656ade68354aa7acafa`

Canonical drift since preregistration affects only DYNTOP-PREDICT research files. It does not change legacy TimeControl, transaction retry, temporal acceptance, or the guarded source patterns.

Primary evidence:

- Actions run: `36419612946`;
- job: `108918899516`;
- source guard: PASS;
- O0 contract test: PASS;
- O2 contract test: PASS.

## What was proved

The current legacy timestep behavior can be decomposed into explicit, typed contracts without changing the controlling formulas.

The executable test-only contract separates:

- accepted-step numerical proposal;
- solver-failure retry;
- day-start compatibility floor;
- hard-event clipping;
- external interval clipping;
- proposal provenance;
- limiting provenance.

The compatibility profile reproduces the current source formulas for:

- low-iteration growth;
- neutral accepted step;
- MAXIT shrink;
- simultaneous grow/shrink ordering;
- DTMAX ceiling;
- DTMIN floor;
- solver retry;
- solver retry floor;
- day-start geometric-mean floor;
- hard-event clamp;
- external interval clamp;
- event clamp after proposal growth.

## Source binding

The source guard confirms current canonical still contains the exact legacy control patterns relied upon by the compatibility model.

This is important because the architecture proof is not a free-standing reimplementation claim. It is explicitly bound to current TimeControl authority.

## Ownership result

The proof demonstrates that:

1. numerical proposal can exist independently from executed dt;
2. event clipping can be represented without mutating the numerical proposal contract;
3. solver retry can be represented separately from accepted-step adaptation;
4. the legacy day-start rule can be isolated as compatibility policy;
5. reason provenance can be deterministic;
6. current behavior does not require one monolithic mutable-control abstraction.

## Decision

TIMEARCH02 advances.

The architecture redesign is now backed by an executable compatibility substrate rather than documentation only.

Required successor:

`F-PE-TIMEARCH03 — timestep decision attribution and shadow-controller observation`.

TIMEARCH03 should instrument or reproduce actual accepted/attempted timestep decisions without changing accepted execution and quantify:

- proposal reasons;
- event clamps by type;
- process clamps;
- solver retry;
- transaction/temporal retry;
- accepted dt distribution;
- deterministic work by reason;
- shadow preferred dt versus actual dt.

## Production boundary

No production `src/**` change in TIMEARCH02.

Final classification:

`QUALIFIED_EXECUTABLE_TIMESTEP_DECISION_CONTRACTS`.
