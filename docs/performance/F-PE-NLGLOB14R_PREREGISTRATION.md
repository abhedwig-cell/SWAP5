# F-PE-NLGLOB14R preregistration — accepted first-retreat TG handoff persistence falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14N3: `QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`;
- restored NLGLOB14N: `QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`;
- NLGLOB14P: `NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`;
- NLGLOB14Q: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`.

## Purpose

NLGLOB14Q established that one full-column TG interval can be solved conservatively from the qualified first-retreat state under actual dry forcing and surface-flux control.

NLGLOB14R tests whether **accepting exactly that one TG interval** produces a stable next-step temporal state or immediately triggers return to saturated mode.

This is research-only state-machine falsification.

## Frozen fixtures

Use the same 12 O05 six-level dry trajectories:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- horizon = 0.05 d;
- NLGLOB14N3 saturation-entry retry-bracket policy;
- unchanged dry forcing;
- unchanged physical mass authority.

## Frozen handoff event

At the qualified first 14 -> 13 retreat origin:

1. switch temporal ownership from persistent saturated KLAG to ordinary TG;
2. preserve dry forcing and actual provider-selected surface route;
3. execute and **accept exactly one** TG interval if it passes all existing TG gates;
4. do not suppress any existing saturation-domain/event detection.

The first accepted TG handoff interval must match the NLGLOB14Q admissible shadow semantics.

## Frozen immediate-following-step test

After accepting the first TG handoff interval:

- run exactly one additional ordinary TG/event-policy interval under the same dry forcing;
- permit the existing saturation-event machinery to re-enter persistent saturated mode if physically triggered;
- do not force either TG continuation or saturated continuation.

Record:

- mode before handoff;
- mode after first accepted TG interval;
- route and saturated-node count after first TG interval;
- second-step outcome;
- whether saturation event localization is invoked;
- whether saturated mode is re-entered;
- number of mode transitions over the two-step handoff window;
- interval and cumulative physical mass;
- finite-state status.

## Control comparison

The corresponding NLGLOB14Q persistent-KLAG trajectory is immutable control authority for the same handoff origin.

For the accepted TG handoff state record bounded state differences against the one-interval NLGLOB14Q shadow candidate when directly available from the same execution path.

No threshold is introduced for scientific equivalence; differences are descriptive unless an existing exact contract applies.

## Frozen classifications

### STABLE_TG_OWNERSHIP_AFTER_HANDOFF

Require all 12 fixtures:

1. first TG interval accepted;
2. second interval completes under ordinary TG without saturated-mode re-entry;
3. no mode chatter;
4. state finite;
5. physical mass closed;
6. route semantics valid.

### IMMEDIATE_SATURATED_MODE_REENTRY

Classify a fixture if the first TG interval is accepted but the immediately following interval triggers the existing saturation-event path and re-enters persistent saturated mode.

### TG_HANDOFF_FIRST_INTERVAL_FAILURE

Classify if the first interval cannot reproduce the qualified NLGLOB14Q admissible path once acceptance is enabled.

### HANDOFF_STATE_OR_MASS_INCONSISTENT

Classify on any accepted-state, transactional, finite-state or physical mass inconsistency.

## Frozen aggregate interpretation

If 12/12 classify `STABLE_TG_OWNERSHIP_AFTER_HANDOFF`:

`NLGLOB14R_STABLE_TG_OWNERSHIP_AFTER_FIRST_RETREAT`.

If 12/12 classify `IMMEDIATE_SATURATED_MODE_REENTRY`:

`NLGLOB14R_FIRST_RETREAT_HANDOFF_CHATTERS_BACK_TO_SATURATED`.

If any fixture is state/mass inconsistent:

`NLGLOB14R_HANDOFF_STATE_OR_MASS_INCONSISTENT`.

Otherwise:

`NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`.

## Consequence

A stable 12/12 result would establish a bounded release rule candidate at first retreat and justify a longer post-release persistence test.

Immediate universal re-entry would falsify first-retreat release as a stable whole-column ownership rule.

Mixed behavior would require route/dt attribution before further release design.

## Stop rules

Do not:

- suppress saturation-event re-entry;
- add hysteresis;
- add a release threshold;
- change provider capacity;
- change forcing, dt or horizon;
- alter MAXIT/BALTOL/tolerances;
- change production source;
- extend beyond the frozen two-step post-handoff window inside NLGLOB14R.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research temporal-mode ownership only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R

BRANCH: `research/f-pe-nlglob14r-accepted-tg-handoff-persistence`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: accept the qualified first TG handoff interval, run one immediate following interval under unchanged event semantics, and classify re-entry/chatter.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
