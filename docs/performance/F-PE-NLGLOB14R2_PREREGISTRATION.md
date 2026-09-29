# F-PE-NLGLOB14R2 preregistration — post-handoff transaction retry recovery

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14Q: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`;
- NLGLOB14R: `NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`;
- NLGLOB14R1: `NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`.

Transaction authority:

- canonical transaction policy default retry scale: `0.5`;
- rejected attempts rollback before retry;
- rejected candidate state never becomes committed authority.

## Purpose

NLGLOB14R1 established that the immediate second TG interval after the accepted first-retreat handoff does not hard-fail. All 12 fixtures return solver `retry_advised`.

NLGLOB14R2 tests whether the already-qualified transaction retry semantics can recover the same nominal second interval without changing solver tolerances, release timing, or physical acceptance rules.

## Frozen fixtures

Use exactly the same 12 O05 six-level handoff fixtures:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- same first-retreat handoff;
- same accepted first TG interval;
- same dry forcing and surface-flux ownership;
- same nominal second interval.

## Frozen retry semantics

For the nominal second interval only:

1. execute the ordinary TG interval at nominal dt exactly as in NLGLOB14R;
2. require the NLGLOB14R1 mechanism to reproduce:
   - solver retry advised;
   - no accepted endpoint from that failed nominal attempt;
3. restore the exact accepted origin state, workspace and accepted accounting;
4. apply the existing transaction retry scale exactly:
   - `dt_retry = 0.5 * dt_nominal`;
5. execute the first half interval with ordinary event-aware TG;
6. if accepted, commit it as accepted internal progress;
7. execute a second half interval of the same `0.5 * dt_nominal` so that the total requested nominal window endpoint is reached;
8. existing saturation-event localization and NLGLOB14N3 retry-as-bracket contraction remain active on both half intervals.

No recursive retry is allowed inside NLGLOB14R2. If either half requests retry or otherwise fails, classify that result rather than shrinking again.

## Frozen transactional requirements

The rejected nominal attempt must leave zero accepted-state leakage in:

- pressure head;
- water content;
- ponding;
- accepted cumulative ledger;
- accepted cumulative runoff.

Diagnostic work counters may retain rejected work.

The two accepted half intervals, if both successful, must advance exactly one original nominal dt in aggregate.

## Frozen diagnostics

Record per fixture:

- nominal second-attempt retry status and solver diagnostics;
- rollback differences after nominal retry-advised attempt;
- first-half outcome:
  - TG accepted;
  - saturation-mode entry;
  - retry/failure;
  - route chain;
  - interval ledger;
- second-half outcome with the same diagnostics;
- number of mode transitions over the recovered nominal window;
- final temporal owner after the recovered window;
- final saturated-node count;
- total accepted mass ledger;
- state finiteness.

## Frozen fixture classifications

### RETRY_RECOVERS_NOMINAL_WINDOW_UNDER_TG

Require:

1. nominal second attempt reproduces retry-advised;
2. rollback is exact;
3. both half intervals are accepted;
4. requested nominal endpoint is reached;
5. no saturated-mode re-entry occurs;
6. state remains finite;
7. physical mass remains closed.

### RETRY_RECOVERS_WITH_SATURATED_REENTRY

Require:

- exact rollback after nominal failure;
- the two-half execution reaches the nominal endpoint;
- existing event logic re-enters saturated mode during either half;
- accepted state and mass remain valid.

### RETRY_HALF_INTERVAL_STILL_RETRY_ADVISED

Classify if either frozen half interval requests retry before the nominal endpoint is recovered.

### RETRY_RECOVERY_HARD_FAILURE

Classify if either half interval hard-fails for a non-retry reason.

### RETRY_RECOVERY_STATE_OR_MASS_INCONSISTENT

Classify on rollback leakage, nonfinite accepted state, time-window mismatch, or physical mass failure.

## Frozen aggregate interpretation

If 12/12 classify `RETRY_RECOVERS_NOMINAL_WINDOW_UNDER_TG`:

`NLGLOB14R2_TRANSACTION_RETRY_RECOVERS_TG_OWNERSHIP`.

If 12/12 recover the nominal window but all re-enter saturated mode:

`NLGLOB14R2_TRANSACTION_RETRY_RECOVERS_WITH_SATURATED_REENTRY`.

If all fail because a half interval still requests retry:

`NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`.

If any transactional/state/mass inconsistency occurs:

`NLGLOB14R2_RETRY_TRANSACTION_INCONSISTENT`.

Otherwise:

`NLGLOB14R2_MIXED_RETRY_RECOVERY`.

## Consequence

A positive TG recovery result would justify a longer accepted post-handoff TG persistence test using ordinary transaction retry semantics.

A saturated re-entry result would identify the first physically/numerically stable ownership return after release.

A still-retry result would require separate bounded recursive-retry attribution, not tolerance changes.

## Stop rules

Do not:

- change retry scale from 0.5;
- permit more than this single retry decomposition in R2;
- increase MAXIT or backtracking;
- change BALTOL/head/ponding tolerances;
- change forcing, dt ladder, provider capacity, release event or route semantics;
- suppress saturation re-entry;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research retry execution only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R2

BRANCH: `research/f-pe-nlglob14r2-transaction-retry-recovery`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: reproduce the nominal second-interval retry, rollback exactly, then execute two half-dt event-aware TG subintervals.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
