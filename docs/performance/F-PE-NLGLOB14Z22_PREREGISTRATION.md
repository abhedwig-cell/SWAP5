# F-PE-NLGLOB14Z22 preregistration — post-14:16 bidirectional continuation

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Parent authority:

- Z21: `QUALIFIED_Z21_BIDIRECTIONAL_PERSISTENCE_TO_13_14`;
- both fine O05 fixtures reproduce the five-change Z20 transient;
- no late ownership recurrence occurs before the next physical retreat;
- exact accepted retreat `13:16 -> 14:16` occurs at:
  - HEAD: 514.6110625 d;
  - RUNOFF: 514.6081875 d;
- mass, residual, rollback, provider and one-face geometry gates remain valid.

## Purpose

Characterize the immediate deeper moving-interface response after accepted tail:

`14:16`

through 540.0 d under exactly the same accepted-state bidirectional ownership semantics.

No new anti-chatter or disappearance semantics are introduced.

## Frozen fixtures

Use exactly the two fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

For each fixture:

1. reproduce the qualified Z21 trajectory through exact accepted `13:16 -> 14:16`;
2. continue unchanged accepted-state bidirectional ownership to 540.0 d or until a hard gate fails;
3. record every later ownership change.

Control/event times are diagnostic only and may not trigger ownership.

## Frozen ownership semantics

Unchanged from Z19-Z21:

- accepted physical state is authority;
- ownership follows exact paired saturated-tail geometry of accepted state;
- one-face moves only;
- retreat and reverse expansion are both permitted;
- no hysteresis;
- no dwell time;
- no fitted h/theta threshold;
- no event-time forcing;
- no event suppression;
- one interface authority.

## Required diagnostics

Per fixture record:

- exact reproduction of the Z21 `13:16 -> 14:16` event;
- every ownership change after accepted `14:16`;
- step/time, direction and pre/post tail;
- final accepted tail at 540 d or stop;
- whether exact `14:16 -> 15:16` occurs;
- whether reverse `14:16 -> 13:16` occurs;
- whether any alternating post-14 chatter occurs;
- finiteness;
- contiguous one-face geometry;
- physical mass ledger;
- nonlinear residual;
- rollback;
- provider route.

## Frozen classifications

### STABLE_14_TO_540

Require:

- Z21 target event reproduced exactly;
- no ownership change after accepted `14:16` through 540 d;
- all hard gates valid.

### NEXT_RETREAT_14_TO_15

Require:

- first ownership change after accepted `14:16` is exact retreat `14:16 -> 15:16`;
- no earlier reverse ownership change;
- hard gates valid.

Continue observation to 540 d and record any later changes.

### REVERSE_AFTER_14

First ownership change after accepted `14:16` is reverse expansion `14:16 -> 13:16`, while hard gates remain valid.

### POST14_CHATTER

Two or more post-14 ownership direction changes form an alternating sequence while hard gates remain valid.

### OTHER_VALID_POST14_RESPONSE

Any other valid contiguous one-face bidirectional sequence.

Any solve, mass, residual, rollback or provider failure:

`NLGLOB14Z22_TRANSACTION_OR_SOLVE_INCONSISTENT`.

Any noncontiguous or skipped-face accepted geometry:

`NLGLOB14Z22_GEOMETRY_INCONSISTENT`.

## Frozen aggregate interpretation

If both fixtures classify `STABLE_14_TO_540`:

`QUALIFIED_Z22_STABLE_14_TO_540`.

If both first move by exact `14:16 -> 15:16`:

`QUALIFIED_Z22_NEXT_RETREAT_14_TO_15`.

If either first reverses:

`NLGLOB14Z22_REVERSE_AFTER_14`.

If either develops alternating post-14 chatter:

`NLGLOB14Z22_POST14_CHATTER`.

If fixtures remain valid but differ:

`NLGLOB14Z22_MIXED_POST14_RESPONSE`.

Hard-gate and geometry failures retain their named classifications.

## Interpretation boundary

Z22 is local characterization only.

It does not establish:

- disappearance semantics;
- zero-tail ownership;
- whole-column TG re-entry;
- production temporal ownership;
- broad material/profile portability.

If `15:16` is reached, any continuation toward `16:16` or disappearance requires a successor whose disappearance semantics are preregistered separately.

## Stop rules

Do not:

- alter dt or forcing;
- tune tolerances;
- add hysteresis/dwell/thresholds;
- suppress ownership events;
- introduce whole-column TG re-entry;
- modify production source.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z22

BASELINE: `93027f24056e971c78ec96ab9390d9d3252457fa`

BRANCH: `research/f-pe-nlglob14z22-post14-bidirectional`

NEXT SAFE STEP: extend the Z21 harness beyond accepted `14:16` to 540 d without changing bidirectional accepted-state ownership semantics.

## Production boundary

Research only. No production source/default change.
