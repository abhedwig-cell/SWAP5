# F-PE-TIMEARCH11 result — AUTO_REFERENCE controller interface

Date: 2026-09-28

Final status:

`QUALIFIED_AUTO_REFERENCE_CONTROLLER_INTERFACE`

Canonical base:

`integration/f-ci-canonical@b7cec379c9ab492208a9c39faf4c65cde6dcac6a`

Qualification authority:

- Actions run: `36429527311`;
- job: `108951821117`;
- conclusion: SUCCESS.

## Contract

TIMEARCH11 adds a production-owned timestep-controller interface with:

- accepted-step context;
- preferred-dt proposal;
- typed proposal provenance;
- independent safety floor/ceiling application;
- legacy compatibility controller;
- null AUTO_REFERENCE controller.

## Legacy compatibility

The legacy compatibility controller reproduces the already-qualified TIMEARCH06 accepted-step formula exactly over the deterministic qualification matrix.

It uses executed accepted dt as the legacy proposal base, preserving current semantics.

## Preferred versus executed separation

The accepted-step context can carry both:

- previous preferred dt;
- actually executed dt;
- event-clipped flag.

The controller proposal object is independent from event clipping.

This preserves the architecture decision that hard-event scheduling and numerical proposal are separate concerns.

## Safety bounds

Retry floor and optional expert ceiling are applied by a separate pure safety operation.

They are not part of controller memory.

This directly implements the TIMEARCH09 semantics:

- DTMIN-like floor is solver/safety ownership;
- DTMAX-like ceiling is optional expert safety ownership.

## AUTO_REFERENCE

The only AUTO_REFERENCE implementation admitted here is a null controller.

It returns unavailable.

The AUTO_REFERENCE numerical profile therefore remains execution-not-ready unless a later controller is separately admitted.

## Preservation

PASS:

- O0/O2 identity;
- TIMEARCH10 preservation;
- no legacy TimeControl source imports the new controller contract;
- no parser change;
- no timestep sequence change;
- no solver/retry/event/physics change.

## Decision

`QUALIFIED_AUTO_REFERENCE_CONTROLLER_INTERFACE`

The architecture is now ready for automatic-controller research without requiring ordinary-user DTMIN/DTMAX and without editing monolithic TimeControl logic in place.

## Required successor

`F-PE-TIMEARCH12 — AUTO_REFERENCE algorithm discovery and qualification`

TIMEARCH12 should compare candidate proposal algorithms behind this interface while:

- keeping hard events exact;
- keeping retry ownership unchanged;
- using internal solver floor and optional safety ceiling only as safety constraints;
- preserving a legacy fallback path;
- separating strict Reference and practical/coupling objectives;
- validating on independent cases.

No candidate should be production-enabled until it beats LEGACY_NUMERICS on a preregistered physical/performance objective.
