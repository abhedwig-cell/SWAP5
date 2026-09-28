# F-PE-TIMEARCH10 closeout — numerical-profile configuration seam

Date: 2026-09-28

Final status:

`QUALIFIED_NUMERICAL_PROFILE_CONFIGURATION_SEAM`

## Decision

SWAP5 now has a configuration-level separation between:

- `LEGACY_NUMERICS`, which can preserve the existing explicit timestep controls exactly;
- `AUTO_REFERENCE`, which can be represented without ordinary-user DTMIN/DTMAX and remains fail-closed until an automatic controller is separately admitted.

No automatic timestep algorithm is enabled by this workunit.

## Meaning for DTMIN and DTMAX

The TIMEARCH09 design decision is now executable at contract level.

Long-term ordinary SWAP5 use does not need to expose DTMIN and DTMAX as mandatory peer inputs.

Target roles remain:

- DTMAX: optional expert/reproducibility safety ceiling;
- DTMIN: internal solver failure floor with optional expert override.

Legacy files can continue to map into LEGACY_NUMERICS unchanged.

## What remains before user-facing migration

The current parser and current TimeControl remain unchanged.

AUTO_REFERENCE cannot become the normal profile until a behavioral controller is qualified.

Therefore the next research question is no longer configuration architecture.

It is controller qualification under the new architecture:

1. preserve exact hard-event scheduling;
2. separate preferred-step memory from event-limited execution;
3. treat any maximum step as safety ceiling rather than normal operating target;
4. preserve explicit retry ownership;
5. qualify physical accuracy and performance on independent cases.

## Recommended successor

`F-PE-TIMEARCH11 — conservative AUTO_REFERENCE controller qualification`.

TIMEARCH11 should not start by choosing a new global DTMAX.

It should use current Reference behavior as the conservative fallback and test whether the qualified preferred-memory/state-history seams can safely reduce policy-imposed fragmentation.

## Production boundary

Only an unused configuration contract is added.

No parser, timestep, solver, physics, event or transaction behavior changes.

