# F-PE-NLGLOB14Z3 preregistration — repaired finest-dt continuation to late retreat

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z1: finest fixed dt `1.5625e-5 d` is blocked by local persistent-KLAG `SW_SOLVE_RETRY_ADVISED` before the late retreat;
- NLGLOB14Z2: `QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`;
- at the first retry in both routes, exact rollback plus `dt/2 + dt/2` recovers the nominal time window and nominal dt resumes without immediate recurrent retry;
- the late accepted physical control retreat `7:16 -> 8:16` is independently exposed near 2.44 d on complete coarser levels.

## Purpose

Determine whether the finest-dt research trajectory can be continued to the late accepted physical retreat using only the already-qualified bounded local recovery mechanism whenever a nominal persistent-KLAG interval returns `retry_advised`.

This workunit tests continuation, not production adaptivity.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- nominal dt = `1.5625e-5 d`;
- horizon = `2.80 d`;
- unchanged NLGLOB14N3 root-controller policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances and work limits.

## Frozen retry policy

For each persistent-KLAG nominal interval:

1. attempt the nominal dt once;
2. if accepted, commit normally;
3. if it returns `retry_advised`, never accept the failed candidate;
4. restore accepted physical state, workspace and accepted accounting exactly;
5. retry the same nominal interval as exactly two half-dt KLAG transactions;
6. if both halves accept, commit the second half endpoint and restore nominal dt;
7. if either half returns retry or hard failure, restore the original nominal origin exactly and stop;
8. do not subdivide below `dt/2`;
9. the same one-level recovery may be used again at a later, distinct nominal interval.

Thus Z3 permits repeated local recoveries over the long trajectory, but never recursive retry depth.

## Required diagnostics

Per route:

- total nominal retry count;
- times/steps of all nominal retries;
- exact rollback differences at every rejected nominal trial;
- half-step outcomes per recovery;
- any failed recovery window;
- physical mass per repaired window and globally;
- accepted saturated-tail sequence;
- accepted `7:16 -> 8:16` event time;
- any reverse/skipped/noncontiguous geometry;
- dynamic-top route;
- final completion status at 2.80 d;
- work counts.

## Frozen classifications

### REPAIRED_FINEST_TRAJECTORY_REACHES_LATE_RETREAT

Require:

- complete 2.80 d trajectory;
- every nominal retry recovered by one `dt/2 + dt/2` window;
- no half-step retry;
- exact rollback;
- mass valid;
- exact accepted `7:16 -> 8:16` transition;
- no reverse/skip/noncontiguous state.

### REPEATED_LOCAL_RECOVERY_BUT_LATE_RETREAT_NOT_REACHED

All retry windows recover and trajectory remains valid, but the late retreat is not reached by 2.80 d.

### BOUNDED_RECOVERY_DEPTH_INSUFFICIENT

At least one half-step itself requests retry.

### REPAIRED_TRAJECTORY_HARD_FAILURE

A non-retry failure occurs after or during a recovery window.

### REPAIRED_TRAJECTORY_TRANSACTION_INCONSISTENT

Any rollback, accepted accounting or physical mass leak.

## Frozen aggregate interpretation

If both routes satisfy `REPAIRED_FINEST_TRAJECTORY_REACHES_LATE_RETREAT`:

`QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`.

If both remain valid but do not reach the event:

`NLGLOB14Z3_LATE_RETREAT_NOT_REACHED`.

If either route needs deeper-than-half subdivision:

`NLGLOB14Z3_BOUNDED_RECOVERY_DEPTH_INSUFFICIENT`.

If route outcomes otherwise differ:

`NLGLOB14Z3_MIXED_REPAIRED_TRAJECTORY`.

Any transaction inconsistency:

`NLGLOB14Z3_REPAIRED_TRANSACTION_INCONSISTENT`.

## Interpretation boundary

A positive Z3 result qualifies a complete finest-dt late-retreat trajectory under a repeated one-level transaction-safe retry policy.

It does not by itself authorize production adaptive stepping.

A positive result may restore a complete four-level event-time refinement ladder for the `7:16 -> 8:16` retreat, to be evaluated in a separately frozen result step if needed.

## Stop rules

Do not:

- recurse below one half-step;
- alter MAXIT/BALTOL;
- change forcing or physical thresholds;
- accept retry candidates;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z3

BASELINE: `544c5020a08b798122004e40a5364e227c3e503e`

BRANCH: `research/f-pe-nlglob14z3-repaired-late-retreat`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: extend the Z2 bounded recovery wrapper to repeated one-level local recoveries and run the two finest-dt fixtures to 2.80 d.

## Production boundary

Research only. No production source or default policy changes.
