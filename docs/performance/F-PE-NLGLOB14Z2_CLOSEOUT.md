# F-PE-NLGLOB14Z2 closeout — local persistent-KLAG retry recovery

Date: 2026-09-29

Final status:

`QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`

Qualification authority:

- run `36613374725`;
- job `109560136975`;
- conclusion: SUCCESS.

## Closure

NLGLOB14Z2 closes positively.

Both blocked finest-dt persistent-KLAG trajectories reproduce the local retry-advised nominal failure, restore the accepted origin exactly, accept two half-duration KLAG transactions, restore the original nominal dt and complete the frozen 0.18 d horizon without recurrent retry.

## Mechanistic conclusion

The Z1 finest-dt blocker is a local nonlinear interval-resolution event, not a hard physical-state failure.

The accepted physical origin is valid and mass-clean.

A single bounded transactional subdivision:

`dt -> dt/2 + dt/2`

is sufficient in both HEAD and RUNOFF.

No tolerance, forcing or physical threshold is changed.

## Direct successor

Open a separately preregistered continuation of the repaired finest-dt trajectory to the late `7:16 -> 8:16` retreat.

The successor must determine whether:

- additional retry-advised intervals occur before the late retreat;
- the same one-level bounded subdivision is sufficient wherever such retries occur;
- the late retreat is reached with valid contiguous accepted state;
- physical mass and rollback remain authoritative.

Do not introduce recursive subdivision or production adaptive stepping without separate qualification.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z2

BRANCH: `research/f-pe-nlglob14z2-local-klag-retry`

QUALIFICATION RUN: `36613374725`

STATUS: closed positive research qualification

QUALIFICATION STATUS: `QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`

NEXT SAFE STEP: preregister repaired finest-dt continuation to the late retreat.

## Production boundary

No production source or default policy change.

`LEGACY_NUMERICS` remains production default.
