# F-PE-NLGLOB14Z20 preregistration — bidirectional chatter lifetime characterization

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent authority:

- NLGLOB14Z19: `NLGLOB14Z19_BIDIRECTIONAL_CHATTER`;
- both fine split fixtures accept exact reverse reclassification `13:16 -> 12:16`;
- no-hysteresis state-derived ownership then oscillates rapidly across `face 11/12 <-> face 12/13`;
- five ownership changes are observed in the first few nominal intervals;
- both 64-interval observations end at accepted tail `13:16`;
- solve, mass, geometry, rollback and provider gates remain valid.

## Purpose

Determine whether the Z19 no-hysteresis ownership chatter is:

1. a finite transient that self-settles under unchanged exact accepted-state semantics; or
2. persistent/recurrent over a materially longer accepted-state window.

This is characterization only.

No anti-chatter rule is introduced in Z20.

## Frozen fixtures

Use the same two fine split fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

For each:

1. reproduce the qualified accepted `12:16 -> 13:16` endpoint;
2. reproduce and accept the exact reverse `13:16 -> 12:16`;
3. continue unchanged bidirectional accepted-state ownership for exactly 4096 nominal accepted intervals after the reverse event.

Use the same exact 140 d checkpoint transport as Z19.

## Ownership semantics

Unchanged from Z19:

- ownership is derived only from the exact paired saturated tail of each accepted state;
- one-face moves only;
- both retreat and re-expansion are permitted;
- no hysteresis;
- no dwell time;
- no fitted h/theta threshold;
- no event-time forcing.

## Required diagnostics

Per fixture record:

- every accepted ownership change and its offset after the committed reverse event;
- direction of each change;
- total ownership-change count;
- longest consecutive alternating burst;
- last ownership-change offset;
- final accepted tail after 4096 intervals;
- whether any ownership change recurs after offset 64;
- whether any ownership change recurs after offset 512;
- whether any ownership change recurs after offset 2048;
- state finiteness;
- geometry consistency;
- physical mass;
- nonlinear residual;
- rollback;
- provider route.

## Frozen classifications

### FINITE_TRANSIENT_CHATTER

Require:

- at least two direction changes occur;
- all ownership changes cease by offset 64;
- no ownership change occurs in offsets 65..4096;
- all hard state/mass/transaction/provider gates remain valid.

### LATE_RECURRENT_CHATTER

Classify if ownership changes cease initially but recur at any offset >64.

### PERSISTENT_CHATTER

Classify if ownership continues changing beyond offset 512 without a stable 512-interval suffix.

### OTHER_VALID_LONG_RESPONSE

Any other valid contiguous one-face bidirectional sequence.

## Frozen aggregate interpretation

If both fixtures classify `FINITE_TRANSIENT_CHATTER`:

`QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`.

If either fixture has recurrence after offset 64:

`NLGLOB14Z20_LATE_RECURRENT_CHATTER`.

If either fixture remains persistently oscillatory beyond offset 512:

`NLGLOB14Z20_PERSISTENT_CHATTER`.

If fixtures differ while remaining valid:

`NLGLOB14Z20_MIXED_CHATTER_LIFETIME`.

Any mass/rollback/provider/nonlinear inconsistency:

`NLGLOB14Z20_TRANSACTION_OR_SOLVE_INCONSISTENT`.

Any noncontiguous/skipped-face geometry:

`NLGLOB14Z20_GEOMETRY_INCONSISTENT`.

## Interpretation boundary

A finite-transient result does not by itself authorize production chatter.

It would establish that the no-hysteresis exact-state semantics self-settle locally and would motivate a later cost/robustness comparison between:

- accepting the finite transient as-is;
- coalescing it transactionally;
- or introducing an explicit anti-chatter state machine.

No such mechanism is selected in Z20.

## Stop rules

Do not:

- alter dt;
- alter forcing;
- tune solver tolerances;
- add hysteresis;
- add dwell time;
- fit physical thresholds;
- suppress ownership events;
- modify production source.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z20

BASELINE: `b6a10f8911a387a1d00486b2f6bb798d48f02fbe`

BRANCH: `research/f-pe-nlglob14z20-chatter-lifetime`

NEXT SAFE STEP: extend the unchanged Z19 bidirectional accepted-state observation from 64 to 4096 nominal intervals.

## Production boundary

Research only. No production source/default change.
