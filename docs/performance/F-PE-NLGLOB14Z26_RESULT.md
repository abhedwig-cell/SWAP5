# F-PE-NLGLOB14Z26 result — event-window nonlinear work characterization

Date: 2026-09-30

Status:

`QUALIFIED_Z26_EVENT_WINDOW_SOLVER_WORK_CHARACTERIZED`

Qualification authority:

- workflow run: `36723523142`;
- HEAD segment-B job: `109921171191`;
- RUNOFF segment-B job: `109921171246`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z26-event-window-work@2aa2c4b98ca0f0bfb8adfeb8eb372c3b6e77dbd6`

## Aggregate result

Both frozen fine O05 fixtures classify:

`EVENT_WINDOW_WORK_CHARACTERIZED`.

Therefore the frozen aggregate classification is:

`QUALIFIED_Z26_EVENT_WINDOW_SOLVER_WORK_CHARACTERIZED`.

The observer-only instrumentation reproduces the qualified Z22 ownership sequences, target retreat times, final tails and hard physical/transaction gates.

## HEAD fine

### Burst 1

Qualified event window:

- event offsets: 0..5;
- six ownership-changing intervals including the committed reverse;
- block-size sequence: 12, 11, 12, 11, 12, 11;
- total Newton iterations: 12;
- mean: 2.0;
- maximum: 2.

Post-settlement control:

- six stable intervals;
- block size: 12 throughout;
- total Newton iterations: 15;
- mean: 2.5;
- maximum: 3.

Event minus post-control total:

`-3 iterations`.

Event/post-control mean ratio:

`0.8`.

No complete pre-event control is available for burst 1 because the observation origin begins with the committed reverse event.

### Burst 2

Qualified event window:

- event offsets: 4,058,840..4,058,848;
- nine ownership-changing intervals;
- block-size sequence alternates 12/13 and ends at 12;
- total Newton iterations: 18;
- mean: 2.0;
- maximum: 2.

Pre-event stable control:

- nine intervals;
- block size: 12;
- total Newton iterations: 9;
- mean: 1.0;
- maximum: 1.

Post-settlement stable control:

- nine intervals;
- block size: 13;
- total Newton iterations: 23;
- mean: about 2.556;
- maximum: 3.

Event minus post-control total:

`-5 iterations`.

Event/post-control mean ratio:

about `0.783`.

The event window is more expensive than the pre-event 12-node stable state, but less expensive than the post-event 13-node stable state.

## RUNOFF fine

### Burst 1

- six ownership-changing intervals;
- block-size sequence: 12, 11, 12, 11, 12, 11;
- total Newton iterations: 12;
- mean: 2.0;
- maximum: 2.

Post-settlement control:

- six stable intervals;
- block size: 12;
- total Newton iterations: 15;
- mean: 2.5;
- maximum: 3.

Event minus post-control total:

`-3 iterations`.

Event/post-control mean ratio:

`0.8`.

Again, no complete pre-event control exists for burst 1.

### Burst 2

- five ownership-changing intervals;
- block-size sequence: 12, 13, 12, 13, 12;
- total Newton iterations: 10;
- mean: 2.0;
- maximum: 2.

Pre-event stable control:

- five intervals;
- block size: 12;
- total Newton iterations: 5;
- mean: 1.0;
- maximum: 1.

Post-settlement stable control:

- five intervals;
- block size: 13;
- total Newton iterations: 13;
- mean: 2.6;
- maximum: 3.

Event minus post-control total:

`-3 iterations`.

Event/post-control mean ratio:

about `0.769`.

The same pattern as HEAD is reproduced.

## Physical and trajectory preservation

The instrumentation reproduces the Z22 authority exactly for the observed event structure:

- Z20 first finite chatter transient reproduced;
- Z21 target `13:16 -> 14:16` reproduced;
- HEAD target time: 514.6110625 d;
- RUNOFF target time: 514.6081875 d;
- HEAD post-14 chatter: 8 changes;
- RUNOFF post-14 chatter: 4 changes;
- final accepted tail at 540 d: `14:16` in both fixtures;
- no solve failure;
- max rollback: 0;
- provider route: `surface-flux`;
- mass and residual gates remain valid.

No evidence indicates that observer instrumentation altered the trajectory.

## Interpretation

The repeated chatter is not a local nonlinear-solver cost spike in these fixtures.

Every ownership-changing interval converges in exactly two Newton iterations.

For both chatter events and both fixtures, the chatter-window mean iteration count is lower than the immediately following stable-control mean.

For the second burst, the event window lies between two regimes:

- stable pre-event `13:16` ownership with block size 12 requires one iteration per interval in the matched window;
- the alternating event window requires two;
- stable post-event `14:16` ownership with block size 13 requires about 2.56 to 2.6.

This strongly suggests that the observed work change is associated more with the change in split/block geometry and local physical trajectory than with direction flipping itself.

The result does not establish that chatter is computationally free. The research solver rebuilds a numerical Jacobian each Newton iteration and block size changes its cost. Newton counts therefore are a work indicator, not a whole-model wall-clock measure.

## Qualified claim boundary

Qualified:

- exact event-window Newton work is characterized for both fine O05 fixtures;
- chatter causes no excess Newton-iteration count relative to matched post-settlement stable windows;
- the second chatter burst requires more iterations than its pre-event stable window and fewer than its post-event stable window;
- instrumentation does not alter the qualified physical/event trajectory.

Not qualified:

- production wall-clock overhead;
- Jacobian/factorization operation counts;
- constitutive evaluation counts;
- broader soil/profile portability;
- coarse-dt behavior;
- zero cost of ownership bookkeeping;
- production mode-7 admission.

## Consequence

The current evidence does not support introducing anti-chatter physics or ownership suppression for performance reasons.

A useful successor should test whether the split/block transition itself, rather than chatter, explains the operation-cost change. That study should compare normalized work by block size and, if feasible, direct residual/Jacobian evaluation counts.

Only if a measurable implementation overhead remains after block-size normalization should chatter-specific runtime handling be reconsidered.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
