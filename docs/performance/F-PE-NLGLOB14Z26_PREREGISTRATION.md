# F-PE-NLGLOB14Z26 preregistration — event-window nonlinear work characterization

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z22: two qualified finite chatter bursts on the fine O05 trajectories;
- Z24: chatter is internal to SWAP under the current groundwater-coupling surface;
- Z25: chatter causes no extra timestep retries, substeps or inserted physical intervals;
- Z25 leaves operation-level solver cost unresolved.

## Purpose

Measure nonlinear solver work on the exact qualified physical trajectory around the two chatter bursts, without suppressing ownership changes or changing timestep/forcing semantics.

This workunit is observer-only instrumentation.

## Frozen fixtures

Use exactly:

- O05 HEAD fine, dt = 6.25e-5 d;
- O05 RUNOFF fine, dt = 6.25e-5 d.

Reproduce the exact Z22 trajectory through 540.0 d.

## Frozen physical semantics

Unchanged from Z22:

- accepted physical state is authority;
- exact paired saturated-tail geometry determines internal ownership;
- bidirectional one-face ownership changes are permitted;
- no hysteresis;
- no dwell;
- no event suppression;
- no tolerance tuning;
- no retry policy change;
- no forcing or dt change.

Instrumentation may record values only. It may not influence control flow.

## Frozen work metric

Primary nonlinear work metric:

`Newton iterations per accepted interval`

using the existing `iters` / `it2` returned by the unchanged research `solve_interval`.

Also record per observed interval:

- accepted step;
- absolute time;
- upper nonlinear-block size `upper_n`;
- accepted tail;
- whether ownership changed on that interval;
- ownership direction if changed;
- Newton iterations;
- final nonlinear residual.

Do not infer Jacobian/residual-evaluation counts that are not explicitly instrumented.

## Frozen event windows

### Burst 1

Include the committed reverse candidate and all immediately consecutive ownership-change intervals until the first accepted interval with unchanged ownership.

Qualified expected ownership sequence:

`13:16 -> 12:16 -> 13:16 -> 12:16 -> 13:16 -> 12:16 -> 13:16`.

The settlement interval is the first following unchanged `13:16` interval.

### Burst 2

Start with the accepted `13:16 -> 14:16` retreat and include every immediately consecutive ownership-change interval until the first accepted interval with unchanged ownership.

Observed Z22 lengths differ by fixture and must not be forced equal.

## Frozen controls

For each burst construct controls from the same physical trajectory.

### Post-settlement control

Use the first N consecutive unchanged-ownership accepted intervals immediately after settlement, where N equals the number of ownership-changing intervals in that burst.

### Pre-event control

Use the last N unchanged-ownership accepted intervals immediately before burst start only if such a complete stable window exists without crossing another ownership event.

If unavailable, classify that pre-control as unavailable rather than substituting a different location.

## Frozen diagnostics

Per fixture and burst report:

- event interval count;
- post-control interval count;
- pre-control availability/count;
- event total Newton iterations;
- event mean Newton iterations;
- event maximum Newton iterations;
- post-control total/mean/max;
- pre-control total/mean/max when available;
- event minus post-control total iterations;
- event/post-control mean ratio;
- event versus pre-control values when available;
- block-size sequence;
- residual hard gates;
- exact ownership sequence reproduction.

## Frozen classifications

### EVENT_WINDOW_WORK_CHARACTERIZED

Require:

- exact Z22 event sequence reproduced;
- physical hard gates remain valid;
- instrumentation is observer-only;
- all event intervals and required post-controls have Newton iteration counts.

### EVENT_WINDOW_WORK_NOT_REPRODUCED

The qualified ownership/event sequence is not reproduced.

### INSTRUMENTATION_ALTERS_TRAJECTORY

Any accepted ownership, state gate, event time or final tail differs from frozen Z22 authority in a way attributable to instrumentation.

### SOLVE_OR_TRANSACTION_INCONSISTENT

Any solve, mass, residual, rollback, provider or geometry hard-gate failure.

## Frozen aggregate

If both fixtures classify `EVENT_WINDOW_WORK_CHARACTERIZED`:

`QUALIFIED_Z26_EVENT_WINDOW_SOLVER_WORK_CHARACTERIZED`.

Otherwise use the corresponding failure classification.

No threshold such as “material” or “negligible” is preregistered in Z26.

Z26 characterizes work. A later decision may interpret production significance.

## Interpretation boundary

Z26 may establish whether chatter intervals require more or fewer Newton iterations than adjacent stable intervals.

It does not by itself establish whole-model wall-clock impact because:

- Newton iteration cost can depend on block size;
- Python research-harness overhead is not production runtime;
- only two fine O05 fixtures are observed.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z26

BASELINE: `214a2fe0089b1ebe57e2cda1c63ec45282554018`

BRANCH: `research/f-pe-nlglob14z26-event-window-work`

NEXT SAFE STEP: add observer-only iteration logging to the Z22 harness and rerun the exact fine trajectories to 540 d.

## Production boundary

Research only. No production source/default change.
