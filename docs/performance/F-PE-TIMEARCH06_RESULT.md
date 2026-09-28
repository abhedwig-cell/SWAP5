# F-PE-TIMEARCH06 result — production timestep decision-service extraction

Date: 2026-09-28

Status: `QUALIFIED_PRODUCTION_DECISION_SERVICE_EXTRACTION`

Canonical base:

`integration/f-ci-canonical@b372305b21012318175b973680f1204e7c5e8dd0`

Qualified branch head:

`6b46e950ae4855dbc8f5af62479afbd7e8049476`

Primary evidence:

- TIMEARCH06 workflow run `36424959331`: SUCCESS;
- canonical qualification run `36424967629`: SUCCESS;
- F-PERF-CANON01 B1 recomposition run `36424967500`: SUCCESS;
- F-PERF-CANON01 D/AHL50 run `36424967613`: SUCCESS;
- F-CI110 reconstructed performance admission run `36424967729`: SUCCESS.

## Production change

TIMEARCH06 introduces one pure production decision service:

`src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90`

It owns only two legacy formulas:

1. accepted-step proposal based on nonlinear iteration count;
2. solver-failure retry duration.

`TimeControl` delegates those arithmetic blocks to the service.

## Preserved semantics

Exact legacy ordering and formulas are preserved for:

- low-iteration growth;
- neutral accepted step;
- MAXIT shrink;
- simultaneous grow/shrink ordering;
- DTMAX ceiling;
- DTMIN floor;
- solver retry reduction;
- solver retry floor.

The following remain unchanged in `TimeControl`:

- event scheduling;
- day-start behavior;
- initialization-time DTMIN/DTMAX mutation;
- output/meteo/rain/runon event logic;
- interception/irrigation/macropore controls;
- mutable legacy flags;
- transaction retry;
- temporal acceptance.

## Provenance

The extracted service now returns typed reason codes for:

- KEEP;
- GROW_LOW_ITER;
- SHRINK_MAX_ITER;
- GROW_THEN_SHRINK;
- SOLVER_RETRY;
- SOLVER_RETRY_FLOOR.

TIMEARCH06 does not yet publish these reasons from runtime execution.

## Preservation evidence

All TIMEARCH06 direct service tests pass at O0/O2 with identity.

The source guard confirms only the preregistered arithmetic blocks were replaced.

The full canonical preservation stack relevant to the modified legacy source passes, including historical F-CI authority, restart, root uptake, DIVDRA, ET, B1 recomposition, AHL and reconstructed performance admission.

No physical equation, numerical formula, event rule or timestep value changes.

## Decision

`QUALIFIED_PRODUCTION_DECISION_SERVICE_EXTRACTION`

This is the first production migration step in the timestep redesign.

It intentionally changes ownership, not behavior.
