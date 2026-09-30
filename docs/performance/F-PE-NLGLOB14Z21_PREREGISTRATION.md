# F-PE-NLGLOB14Z21 preregistration — long-horizon bidirectional persistence to 13:16 -> 14:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Parent authority:

- Z20: `QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`;
- both fine O05 fixtures exhibit exactly five accepted ownership changes at offsets 1..5 after the committed reverse event;
- no ownership change recurs through offset 4096;
- both settle at accepted tail `13:16`;
- state, mass, residual, rollback and provider gates remain valid.

## Purpose

Determine whether the self-settled no-hysteresis bidirectional split trajectory remains physically and transactionally coherent over the long interval to the independently qualified control retreat:

`13:16 -> 14:16`.

This workunit does not introduce anti-chatter semantics.

## Frozen fixtures

Use exactly the two fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

For each fixture:

1. reproduce the accepted `12:16 -> 13:16` endpoint;
2. reproduce and accept the exact reverse `13:16 -> 12:16`;
3. reproduce the Z20 finite five-change alternating transient and self-settle at `13:16`;
4. continue the unchanged accepted-state bidirectional ownership until either:
   - the first exact accepted `13:16 -> 14:16` event is reached; or
   - 540.0 d is reached; or
   - a frozen hard gate fails.

Control event times are diagnostic only and must not trigger ownership.

Reference control evidence:

- HEAD fine: approximately 514.66475 d;
- RUNOFF fine: approximately 514.6615625 d.

## Frozen ownership semantics

Unchanged from Z19/Z20:

- accepted physical state is authority;
- ownership is derived only from exact paired saturated-tail geometry of the accepted state;
- one-face moves only;
- retreat and reverse expansion are both permitted;
- no hysteresis;
- no dwell time;
- no fitted h/theta threshold;
- no event-time forcing;
- no event suppression;
- one interface authority.

## Execution-only checkpointing

Long-horizon execution may be split across GitHub jobs.

Checkpointing is execution-only and must preserve, bit-exactly:

- accepted h state;
- accepted theta state;
- accepted step/time;
- current ownership/tail;
- accumulated hard-gate maxima;
- complete ownership-event history needed for classification.

Checkpoint transport may not:

- advance physical time;
- alter dt;
- recompute or smooth accepted state;
- reset ownership memory;
- discard a previously observed ownership event;
- change any scientific gate or classification.

Planned checkpoint boundaries are execution details, not physical triggers.

## Required diagnostics

Per fixture record:

- complete accepted ownership-change sequence after the committed reverse event;
- event offset, absolute step/time and direction;
- whether any ownership change occurs after the Z20 stable suffix;
- whether any late reverse expansion occurs before the target retreat;
- target `13:16 -> 14:16` event time if reached;
- final accepted tail;
- accepted interval count;
- finiteness;
- contiguous geometry;
- one-face geometry;
- physical mass ledger;
- nonlinear residual;
- rollback;
- provider route;
- exact checkpoint roundtrip at every execution boundary.

## Frozen classifications

### BIDIRECTIONAL_PERSISTENCE_TO_13_14

Require all of:

- the Z20 five-change transient is reproduced;
- no ownership change occurs after the transient until the target event;
- the first later ownership change is exact accepted retreat `13:16 -> 14:16`;
- no reverse expansion or skipped face occurs in the stable interval;
- all hard state/mass/transaction/provider gates remain valid.

### LATE_RECURRENT_CHATTER_BEFORE_13_14

Any ownership change occurs after the Z20 stable suffix and before an accepted target `13:16 -> 14:16` event, while geometry and hard gates remain valid.

### TARGET_NOT_REACHED_BY_540D

The trajectory remains valid through 540.0 d but no exact accepted `13:16 -> 14:16` event occurs.

### OTHER_VALID_LONG_RESPONSE

Any other valid contiguous one-face bidirectional sequence.

Any solve, mass, residual, rollback or provider failure:

`NLGLOB14Z21_TRANSACTION_OR_SOLVE_INCONSISTENT`.

Any noncontiguous or skipped-face accepted geometry:

`NLGLOB14Z21_GEOMETRY_INCONSISTENT`.

Any checkpoint non-identity:

`NLGLOB14Z21_EXECUTION_CHECKPOINT_INCONSISTENT`.

## Frozen aggregate interpretation

If both fixtures classify `BIDIRECTIONAL_PERSISTENCE_TO_13_14`:

`QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`.

If either fixture has late valid recurrence before the target event:

`NLGLOB14Z21_LATE_RECURRENT_BIDIRECTIONAL_CHATTER`.

If either fixture fails a hard transaction/solve/provider gate:

`NLGLOB14Z21_TRANSACTION_OR_SOLVE_INCONSISTENT`.

If either fixture fails geometry:

`NLGLOB14Z21_GEOMETRY_INCONSISTENT`.

If execution checkpoint identity fails:

`NLGLOB14Z21_EXECUTION_CHECKPOINT_INCONSISTENT`.

If fixtures remain valid but differ materially:

`NLGLOB14Z21_MIXED_LONG_HORIZON_RESPONSE`.

## Interpretation boundary

A positive Z21 result would establish long-horizon research semantics for the two fine O05 fixtures only.

It would not by itself authorize:

- production temporal ownership;
- accepting chatter cost in production;
- event coalescing;
- hysteresis or dwell;
- later retreat beyond 14:16;
- disappearance;
- whole-column TG re-entry.

## Stop rules

Do not:

- tune tolerances;
- alter dt or forcing;
- introduce local retry unless a separately preregistered successor is opened after exposure;
- use control event times as triggers;
- add hysteresis/dwell/thresholds;
- suppress ownership events;
- modify production source.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z21

BASELINE: `ab634913beb01f497fd768eba0370144d3b622fa`

BRANCH: `research/f-pe-nlglob14z21-long-horizon-bidirectional`

NEXT SAFE STEP: implement segmented exact-checkpoint execution of unchanged Z20 bidirectional semantics to the first accepted `13:16 -> 14:16` event or 540 d.

## Production boundary

Research only. No production source/default change.
