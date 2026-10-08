# F-PE-NLGLOB14Q preregistration — first-retreat transactional shadow TG solve

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14N3: `QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`;
- restored NLGLOB14N: `QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`;
- NLGLOB14O: `NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`;
- NLGLOB14P: `NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`.

## Purpose

NLGLOB14P established that the existing full-column head-space TG predictor is finite and constitutively admissible at the first retreat accepted state.

NLGLOB14Q tests the next bounded question:

can exactly one ordinary full-column TG interval be evaluated transactionally from that accepted retreat-origin state under the actual dry-phase forcing and current provider-selected surface route, without committing the shadow result?

The persistent saturated-KLAG trajectory remains the accepted control trajectory.

## Frozen fixtures

Use the same 12 six-level O05 trajectories:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- horizon = 0.05 d;
- NLGLOB14N3 saturation-root retry-bracket policy;
- unchanged dry forcing;
- unchanged physical mass authority.

## Frozen handoff origin

Use the same `RETREAT_HANDOFF_ORIGIN` as NLGLOB14O/P:

- first accepted state after the 14 -> 13 retreat;
- node 3 unsaturated;
- nodes 4:16 saturated;
- contiguous lower saturated block;
- finite, mass-clean accepted state.

## Frozen shadow-trial semantics

At RETREAT_HANDOFF_ORIGIN:

1. save the complete accepted physical state and accepted accounting;
2. keep the dry-phase forcing active:
   - precipitation = 0;
   - existing bare-soil evaporation forcing;
   - existing ponded-water evaporation forcing;
3. use the actual provider-selected current surface route at the handoff origin, expected to be surface-flux where physically selected;
4. evaluate one ordinary provider-consistent full-column TG interval of duration equal to the trajectory dt;
5. record the shadow outcome;
6. never commit the shadow candidate;
7. restore accepted physical state and accepted accounting exactly;
8. continue the persistent saturated-KLAG control trajectory unchanged.

The shadow trial is observation only.

## Frozen shadow diagnostics

For each fixture record:

- shadow TG origin route;
- predictor route;
- endpoint route;
- accepted-candidate route if reached;
- solver status;
- retry advised;
- terminal reason;
- nonlinear/backtracking/Jacobian/linear work;
- shadow candidate finiteness;
- shadow interval mass ledger if a candidate reaches the normal TG acceptance calculation;
- saturated-node count in the shadow candidate;
- whether node 3 or any lower node immediately crosses/re-enters a saturation boundary;
- exact rollback differences for:
  - pressure head;
  - water content;
  - ponding;
  - cumulative ledger;
  - cumulative runoff.

## Frozen classifications

### SHADOW_TG_INTERVAL_ADMISSIBLE

A fixture qualifies only if:

1. shadow TG interval completes its ordinary TG acceptance path;
2. shadow state is finite;
3. shadow mass is closed under the unchanged authority;
4. provider route is internally consistent for the shadow interval;
5. rollback is exact;
6. no rejected/shadow state leaks into the persistent-KLAG control trajectory.

### SHADOW_TG_IMMEDIATE_SATURATION_REENTRY

Classify if the shadow TG path is otherwise evaluable but immediately encounters the existing saturation-event/domain condition that would return ownership to saturated mode.

### SHADOW_TG_SOLVER_OR_ROUTE_FAILURE

Classify if the shadow interval fails before a valid TG candidate because of solver or route inconsistency.

### SHADOW_TG_STATE_OR_MASS_INCONSISTENT

Classify if state, rollback or physical mass consistency fails.

## Frozen aggregate interpretation

If 12/12 classify `SHADOW_TG_INTERVAL_ADMISSIBLE`:

`NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`.

If 12/12 classify `SHADOW_TG_IMMEDIATE_SATURATION_REENTRY`:

`NLGLOB14Q_FIRST_RETREAT_CAUSES_IMMEDIATE_TG_REENTRY`.

If all failures are solver/route failures:

`NLGLOB14Q_FULL_COLUMN_TG_SHADOW_SOLVE_NOT_ADMISSIBLE`.

If any state/mass/rollback inconsistency occurs:

`NLGLOB14Q_SHADOW_TRANSACTION_INCONSISTENT`.

Otherwise:

`NLGLOB14Q_MIXED_SHADOW_HANDOFF`.

## Consequence

A positive 12/12 shadow result may justify a separately preregistered one-interval accepted handoff/re-entry falsification.

An immediate re-entry result would show that first retreat is not sufficient for stable whole-column TG ownership.

A solver/route failure would require attribution before any mode switch.

## Stop rules

Do not:

- commit the shadow TG state;
- change forcing;
- reuse the original wet-entry route when the current provider route differs;
- change dt;
- change provider capacity;
- change MAXIT, BALTOL or other tolerances;
- suppress saturation re-entry;
- change production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research shadow execution only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Q

BRANCH: `research/f-pe-nlglob14q-retreat-shadow-tg-solve`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement one transactionally rolled-back TG shadow interval at the 12 qualified first-retreat origins while preserving dry forcing and actual provider route.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
