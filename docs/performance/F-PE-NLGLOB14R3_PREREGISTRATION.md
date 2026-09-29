# F-PE-NLGLOB14R3 preregistration — bounded recursive post-handoff retry-depth attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14Q: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`;
- NLGLOB14R: `NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`;
- NLGLOB14R1: `NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`;
- NLGLOB14R2: `NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`.

Canonical transaction authority:

- retry scale = `0.5`;
- maximum retries = `8`;
- exact rollback before every retry;
- rejected candidates never become committed state.

## Purpose

NLGLOB14R2 established that one application of the qualified 0.5 retry scale is insufficient for all 12 post-handoff second-interval origins.

NLGLOB14R3 asks only:

at what bounded retry depth does the existing transaction policy first produce accepted internal progress from that same second-interval origin, or is the retry budget exhausted?

No full nominal-window completion is required in R3.

## Frozen fixtures

Use exactly the 12 O05 six-level handoff fixtures:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- same accepted first-retreat TG handoff;
- same second-interval accepted origin;
- same dry forcing and surface-flux ownership.

## Frozen recursive retry policy

For each fixture:

1. execute the nominal second TG interval at `dt_nominal`;
2. require retry-advised as established by NLGLOB14R1;
3. rollback exactly to the accepted second-interval origin;
4. for retry depth `r = 1..8`:
   - set `dt_r = dt_nominal * 0.5^r`;
   - start every retry from the exact same accepted origin and restored workspace/accounting;
   - execute one ordinary event-aware TG interval;
   - if retry-advised, discard and continue to the next depth;
   - if accepted, stop immediately and record that first accepted progress;
   - if hard failure or state/mass inconsistency occurs, stop fail-closed.

The retry attempts are alternative attempts from one checkpoint. They are not cumulative half-steps.

Existing saturation-event machinery and NLGLOB14N3 saturation-root retry-as-bracket handling remain active.

## Frozen diagnostics

For every retry depth record:

- retry depth;
- attempted dt;
- solver retry/hard-failure outcome;
- temporal owner after the attempt;
- saturation-mode entry if any;
- saturated-node count;
- route chain;
- state finiteness;
- attempt work diagnostics;
- exact rollback diagnostics after every rejected attempt.

For the first accepted retry record:

- accepted retry depth;
- accepted internal dt;
- owner = TG or persistent saturated mode;
- accepted saturated-node count;
- accepted interval physical mass ledger.

## Frozen fixture classifications

### ACCEPTED_TG_PROGRESS_AT_BOUNDED_RETRY

Classify if a retry depth 1..8 produces accepted progress while saturated mode remains off and all state/mass gates pass.

### ACCEPTED_SATURATED_REENTRY_AT_BOUNDED_RETRY

Classify if an accepted retry depth 1..8 reaches accepted internal progress through the existing saturation-event path and persistent saturated mode owns the accepted endpoint.

### RETRY_BUDGET_EXHAUSTED

Classify if all 8 retry depths return retry-advised with exact rollback and no accepted progress.

### RECURSIVE_RETRY_HARD_FAILURE

Classify on a non-retry hard failure before accepted progress.

### RECURSIVE_RETRY_STATE_OR_MASS_INCONSISTENT

Classify on rollback leakage, nonfinite accepted state, or accepted physical-mass failure.

## Frozen aggregate interpretation

If 12/12 classify `ACCEPTED_TG_PROGRESS_AT_BOUNDED_RETRY`:

`NLGLOB14R3_BOUNDED_RETRY_FINDS_TG_PROGRESS`.

If 12/12 classify `ACCEPTED_SATURATED_REENTRY_AT_BOUNDED_RETRY`:

`NLGLOB14R3_BOUNDED_RETRY_FINDS_SATURATED_REENTRY`.

If 12/12 exhaust retries:

`NLGLOB14R3_RETRY_BUDGET_EXHAUSTED`.

If any state/mass inconsistency occurs:

`NLGLOB14R3_RETRY_TRANSACTION_INCONSISTENT`.

Otherwise:

`NLGLOB14R3_MIXED_RETRY_DEPTH`.

## Consequence

R3 characterizes only first accepted internal progress.

It does not qualify completion of the full nominal second interval or the remaining trajectory.

If bounded retries find TG progress, a successor may test whole-window reconstruction using the same transaction policy.

If accepted progress re-enters saturated mode, that is a direct ownership signal for the post-release state.

If the budget exhausts, release at first retreat remains numerically unsupported under current solver/retry authority.

## Stop rules

Do not:

- change retry scale from 0.5;
- exceed 8 retries;
- accumulate rejected retry states;
- change solver tolerances or iteration limits;
- change forcing, release timing, provider capacity or event semantics;
- suppress saturation re-entry;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research retry-depth characterization only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R3

BRANCH: `research/f-pe-nlglob14r3-bounded-retry-depth`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: replay the frozen second-interval origin at retry depths 1..8, restoring exactly before every attempt, and stop at first accepted internal progress.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
