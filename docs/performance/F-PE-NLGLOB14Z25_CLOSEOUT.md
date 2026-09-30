# F-PE-NLGLOB14Z25 closeout — chatter burden

Date: 2026-09-30

Final status:

`QUALIFIED_Z25_NO_TIMESTEP_RETRY_BURDEN_OPERATION_COST_UNRESOLVED`

Qualification authority:

- workflow run `36722547343`;
- job `109911085800`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z25 closes the timestep/retry-burden question.

For both fine O05 trajectories, the observed moving-interface chatter:

- occurs only on nominal accepted intervals;
- preserves exact dt across each burst;
- inserts no additional physical intervals;
- triggers no explicit retry/substep sequence;
- remains mass-, residual- and rollback-clean.

The unresolved quantity is operation-level cost inside those intervals.

## Direct successor

Preregister a narrowly instrumented event-window study that measures solver work around the two qualified chatter bursts and matched stable intervals.

Required counters should include, where available:

- nonlinear iteration count;
- residual evaluations;
- Jacobian construction/factorization or equivalent;
- constitutive evaluations;
- split-block dimension;
- wall-clock timing only as secondary evidence.

The successor must preserve the exact physical and ownership trajectory.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z25

BRANCH: `research/f-pe-nlglob14z25-chatter-burden`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `d9f7447dbd0e5e280179a76c146931b25f40b8cc`

QUALIFICATION STATUS: `QUALIFIED_Z25_NO_TIMESTEP_RETRY_BURDEN_OPERATION_COST_UNRESOLVED`

NEXT SAFE STEP: instrument local event windows without suppressing chatter or changing dt/forcing.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
