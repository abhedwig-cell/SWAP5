# F-PE-NLGLOB14R preregistration — accepted first-retreat TG handoff and re-entry falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14N3: `QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`;
- restored NLGLOB14N: `QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`;
- NLGLOB14Q: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`.

## Purpose

NLGLOB14Q established that one full-column TG interval can be evaluated transactionally from the first-retreat accepted state, but the shadow candidate still contains 13 saturated nodes.

NLGLOB14R tests whether actual temporal ownership can transfer at first retreat without immediate or repeated re-entry to persistent saturated mode.

This remains research/test-only.

## Frozen fixtures

Use the same 12 six-level O05 trajectories:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- horizon = 0.05 d;
- NLGLOB14N3 saturation-root retry-bracket policy;
- unchanged dry forcing;
- unchanged physical mass authority.

For every experimental fixture also retain the corresponding persistent-saturated-KLAG trajectory as the control authority.

## Frozen handoff timing

The accepted 14 -> 13 retreat endpoint remains an ordinary persistent-KLAG accepted state.

At that state set only:

`HANDOFF_PENDING = true`.

Do not execute an extra interval.

On the immediately following nominal interval:

1. use the exact accepted retreat state as origin;
2. keep the actual dry forcing active;
3. use surface-flux as selected by the current provider;
4. execute one ordinary provider-consistent full-column TG interval;
5. if and only if that TG interval is accepted, commit it as the accepted interval endpoint;
6. release persistent saturated-mode ownership for subsequent intervals.

Thus model time advances by exactly one dt per loop interval.

## Post-handoff policy

After a successful handoff interval:

- ordinary event-aware TG execution owns the column;
- dry forcing remains active independently of the persistent-saturated-mode flag;
- the existing saturation-event machinery remains active;
- NLGLOB14N3 retry-as-bracket contraction remains active;
- if the existing event logic enters saturated mode again, that re-entry is accepted and persistent saturated KLAG resumes.

No suppression or hysteresis is introduced.

## Frozen diagnostics

Record per fixture:

- retreat step;
- handoff interval step;
- handoff TG success/failure;
- handoff route chain;
- handoff interval ledger;
- saturation-node count after the committed TG handoff;
- number and steps of saturated-mode entries after handoff;
- first post-handoff re-entry delay in accepted intervals;
- total TG-owned intervals after handoff;
- total saturated-KLAG intervals after any re-entry;
- final saturated-node count;
- final storage;
- final state finiteness;
- max interval and cumulative physical mass ledger.

Compare final storage and selected head/theta state diagnostics against the unchanged persistent-KLAG control. These differences are descriptive and have no post-hoc acceptance threshold.

## Frozen classifications

### STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT

Require:

1. handoff TG interval is accepted;
2. full horizon completes;
3. no saturated-mode re-entry occurs after handoff;
4. state remains finite;
5. physical mass remains closed.

### IMMEDIATE_SATURATED_MODE_REENTRY

Classify if the handoff TG interval is accepted and saturated mode re-enters on the immediately following accepted interval.

### DELAYED_SATURATED_MODE_REENTRY

Classify if the handoff TG interval is accepted and saturated mode re-enters later than the immediately following accepted interval.

### HANDOFF_TG_INTERVAL_FAILED

Classify if the first committed TG handoff interval fails or requests retry without producing an accepted endpoint.

### HANDOFF_STATE_OR_MASS_INCONSISTENT

Classify if accepted-state continuity, finiteness or physical mass fails.

## Frozen aggregate interpretation

If 12/12 classify `STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT`:

`NLGLOB14R_STABLE_FULL_COLUMN_TG_RELEASE_SIGNAL`.

If 12/12 classify `IMMEDIATE_SATURATED_MODE_REENTRY`:

`NLGLOB14R_FIRST_RETREAT_RELEASE_CHATTERS_IMMEDIATELY`.

If every successful handoff eventually re-enters saturated mode but timing is not uniformly immediate:

`NLGLOB14R_FIRST_RETREAT_RELEASE_REENTERS_SATURATED_MODE`.

If all handoff intervals fail:

`NLGLOB14R_ACCEPTED_TG_HANDOFF_NOT_ADMISSIBLE`.

If any accepted-state or mass inconsistency occurs:

`NLGLOB14R_HANDOFF_STATE_OR_MASS_INCONSISTENT`.

Otherwise:

`NLGLOB14R_MIXED_HANDOFF_REENTRY`.

## Consequence

A stable 12/12 signal would justify a broader event-semantics requalification with first-retreat release enabled.

Uniform immediate re-entry would falsify first-retreat as a useful whole-column release event despite the positive one-step shadow result.

Delayed re-entry would require attribution of the subsequent saturation event before any production policy.

## Stop rules

Do not:

- add hysteresis;
- suppress re-entry;
- change the retreat event;
- change capacity regularization;
- change dt, forcing, MAXIT, BALTOL or route semantics;
- alter physical mass gates;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research state-machine policy only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R

BRANCH: `research/f-pe-nlglob14r-accepted-handoff-reentry`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement pending next-interval TG handoff while preserving dry forcing and existing saturation re-entry machinery.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
