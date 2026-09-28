# F-PE-TIMEARCH11 preregistration — AUTO_REFERENCE controller interface

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b7cec379c9ab492208a9c39faf4c65cde6dcac6a`

Parent authority:

- TIMEARCH09: ordinary users should not need DTMIN/DTMAX long-term;
- TIMEARCH10: LEGACY_NUMERICS and fail-closed AUTO_REFERENCE configuration seam qualified;
- TIMEARCH06-08: production decision service, decision trace and preferred-step shadow memory qualified.

## Purpose

Define the production-owned controller contract that AUTO_REFERENCE will eventually use.

This workunit must not introduce an aggressive adaptive algorithm.

It must prove that:

1. a controller can receive accepted-step information without reading rejected physical state;
2. it can return a preferred dt separately from hard-event execution clipping;
3. a solver retry floor and optional expert ceiling are explicit safety constraints rather than proposal memory;
4. missing/unqualified controller authority fails closed;
5. the current legacy algorithm can be represented as a compatibility controller through the same interface;
6. no current production execution is switched to AUTO_REFERENCE.

## Accepted-step context

The controller input may contain only committed/accepted numerical information:

- previous accepted dt;
- previous preferred dt if available;
- executed dt;
- event-clipped flag;
- nonlinear iteration count;
- backtracking count;
- internal retry count;
- optional normalized state/history summary;
- accepted time.

Rejected physical trial state is excluded.

## Proposal result

The controller returns:

- preferred dt;
- typed proposal reason;
- available flag.

It does not apply hard-event clipping.

It does not mutate solver retry state.

It does not commit physical state.

## Safety application

A separate pure operation applies:

- internal retry floor;
- optional expert safety ceiling.

Safety bounds are not controller memory.

## Initial implementations

### LEGACY_COMPAT_CONTROLLER

Uses the already-qualified TIMEARCH06 accepted-step formula.

Given equivalent context/configuration it must reproduce the current preferred-dt decision exactly.

### AUTO_REFERENCE_NULL_CONTROLLER

Always returns unavailable.

This is the only AUTO_REFERENCE implementation admitted in TIMEARCH11.

Therefore AUTO_REFERENCE remains execution-not-ready.

## Qualification gates

- legacy compatibility decision identity over a broad deterministic matrix;
- event-clipped/executed dt can differ from preferred dt without modifying the preferred proposal object;
- expert ceiling clips a proposal only in the safety layer;
- internal floor raises too-small proposals only in the safety layer;
- null automatic controller returns unavailable;
- no legacy TimeControl source imports the new AUTO controller interface;
- O0/O2 identity;
- TIMEARCH10 preservation remains green.

Possible status:

`QUALIFIED_AUTO_REFERENCE_CONTROLLER_INTERFACE`

No automatic algorithm admission is permitted here.
