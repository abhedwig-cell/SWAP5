# F-PE-NLGLOB14N preregistration — refined first-retreat event-time convergence

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Parent authority:

- NLGLOB14L: universal partial retreat after a 14-node saturation maximum;
- NLGLOB14M: `NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`.

## Purpose

NLGLOB14M established that the first 14 -> 13 retreat event exists, is physically consistent and is cleanly bracketed, but the accepted-state linear `h_3=0` event-time estimate did not satisfy the frozen refined convergence gate.

NLGLOB14N tests whether the same event-time estimator converges when the timestep ladder is extended to two finer levels.

No event definition, interpolation rule or release semantics are changed.

## Frozen fixtures

Reuse the same O05 dry forcing-reversal setup and route families:

- HEAD;
- RUNOFF;
- total horizon = `0.05 d`;
- unchanged persistent saturated KLAG policy;
- unchanged dry forcing;
- unchanged mass authority.

Use the six dt levels:

- `2.5e-4 d`;
- `1.25e-4 d`;
- `6.25e-5 d`;
- `3.125e-5 d`;
- `1.5625e-5 d`;
- `7.8125e-6 d`.

The two new finest levels are frozen before result exposure.

## Frozen event definition

Use exactly the NLGLOB14M event:

- peak saturated set contains nodes 3:16;
- retreat event is the first loss of node 3 while nodes 4:16 remain saturated;
- event function `g(t)=h_3(t)`;
- physical boundary `g=0`.

For every fixture identify the last accepted state A with node 3 saturated and the immediately following accepted state B with node 3 unsaturated.

Require:

- `h_A >= 0`;
- `h_B < 0`;
- saturation indicators agree;
- nodes 4:16 remain saturated;
- bracket width equals dt;
- state is finite and mass-clean.

## Frozen estimator

Use the unchanged one-shot linear estimate:

`t_root = t_A + (0-h_A)/(h_B-h_A) * (t_B-t_A)`.

No root solve and no state acceptance occurs at `t_root`.

## Frozen convergence gates

For each route family separately, define the two new finest estimates:

- `T_1 = t_root(dt=1.5625e-5)`;
- `T_2 = t_root(dt=7.8125e-6)`.

The route family qualifies only if:

1. all six brackets are valid;
2. all event estimates lie inside their brackets;
3. `|T_2-T_1| <= 2*7.8125e-6 d = 1.5625e-5 d`;
4. the new finest difference is smaller than the NLGLOB14M finest-pair difference for that route;
5. states remain finite and physical mass remains closed.

The older four levels remain evidence but do not define the new threshold.

## Frozen aggregate classifications

If both route families qualify:

`QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`.

If exactly one route family qualifies:

`NLGLOB14N_MIXED_REFINED_RETREAT_CONVERGENCE`.

If neither route family qualifies while all brackets remain valid:

`NLGLOB14N_RETREAT_EVENT_TIME_STILL_NOT_CONVERGED`.

If any bracket/state/mass consistency requirement fails:

`NLGLOB14N_RETREAT_EVENT_STATE_INCONSISTENT`.

If coverage is incomplete:

`BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`.

## Consequence

A positive result would qualify the existing node-3 retreat event estimator at refined dt and may justify a separately preregistered test-only release experiment.

A negative result must not trigger threshold relaxation. It instead requires attribution of estimator error versus accepted-trajectory error.

## Stop rules

Do not:

- change the event definition;
- change the interpolation formula;
- relax the convergence threshold after results;
- extend the horizon;
- alter forcing or saturation indicators;
- switch temporal mode;
- introduce a release threshold.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14n-refined-retreat-convergence`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: extend the NLGLOB14M observation runner to the two frozen finer dt levels and execute the six-level qualification.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
