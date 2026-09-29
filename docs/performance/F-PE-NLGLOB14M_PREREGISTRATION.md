# F-PE-NLGLOB14M preregistration — first saturated-block retreat event localization

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`;
- NLGLOB14L: all 8 fixed 0.05 d dry fixtures show `PARTIAL_RETREAT_AFTER_PEAK`.

## Purpose

NLGLOB14L established that the contiguous lower saturated block first expands to 14 nodes and later retreats to 13 nodes in every fixture.

NLGLOB14M asks whether the **first retreat** can be localized as a physical saturation-boundary event with timestep-convergent timing.

No release switch is introduced.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14L fixtures:

- material O05;
- TG wet-entry mode;
- wet-entry routes HEAD and RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- fixed total horizon = 0.05 d;
- unchanged dry forcing;
- unchanged complete same-route research policy;
- unchanged S0/R0 endpoint certificates;
- unchanged physical mass authority.

## Frozen retreat-node definition

For each fixture:

1. determine the maximum saturated-node count reached during the dry phase;
2. identify the shallowest saturated node while that maximum is active;
3. call this node `RETREAT_NODE`.

NLGLOB14L observed a maximum count of 14, implying node 3 for the existing fixtures, but NLGLOB14M derives the node from the state rather than hard-coding it.

## Frozen event bracket

After the final accepted state at maximum saturated-node count, identify:

- `A`: the last accepted state where RETREAT_NODE is saturated under both existing indicators;
- `B`: the first later accepted state where RETREAT_NODE is unsaturated under both existing indicators.

Require:

- SAT_H and SAT_THETA agree at A and B;
- `h_A >= 0`;
- `h_B < 0`;
- `theta_A = theta_s`;
- `theta_B < theta_s`;
- B immediately follows A in the accepted dry trajectory.

The event bracket is:

`[t_A, t_B]`.

No pressure-head threshold other than the existing physical saturation boundary `h=0` is introduced.

## Frozen continuous event estimate

Within the bracket define a one-shot linear head-root estimate:

`t_root = t_A + (0-h_A)/(h_B-h_A) * (t_B-t_A)`.

Require:

`t_A <= t_root <= t_B`.

This estimate is observational only.

No state is recomputed at t_root and no event split is performed.

## Frozen convergence test

For each route family separately, order the four root estimates by dt refinement.

Let:

- `D_mid = |t_root(dt=6.25e-5) - t_root(dt=1.25e-4)|`;
- `D_fine = |t_root(dt=3.125e-5) - t_root(dt=6.25e-5)|`.

A route family has a `RETREAT_ROOT_CONVERGENCE_SIGNAL` only if:

1. all four event brackets are valid;
2. all root estimates lie inside their own brackets;
3. `D_fine <= D_mid`;
4. `D_fine <= 2 * 6.25e-5 d`;
5. physical mass remains closed and states remain finite.

The coarsest dt result is retained as evidence but is not required to be asymptotic.

## Frozen aggregate classifications

If both HEAD and RUNOFF route families satisfy the convergence signal:

`NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED`.

If one route family passes and the other fails:

`NLGLOB14M_MIXED_RETREAT_EVENT_LOCALIZATION`.

If neither route family passes while coverage remains valid:

`NLGLOB14M_RETREAT_EVENT_DT_SENSITIVE`.

If any bracket lacks saturation-indicator consistency, finite state, or physical mass:

`NLGLOB14M_RETREAT_EVENT_STATE_INCONSISTENT`.

If coverage is incomplete:

`BLOCKED_NLGLOB14M_RETREAT_EVENT_LOCALIZATION`.

## Consequence

A positive localization result may authorize a separately preregistered **test-only release-at-retreat-event** experiment.

That later workunit must still prove:

- transactional state continuity;
- no water duplication/loss;
- no route inconsistency;
- no immediate release/re-entry chatter;
- preserved smooth TIMEINT16C second-order behavior when the release event is inactive.

NLGLOB14M itself does not switch temporal mode.

## Stop rules

Do not:

- fit a pressure-head release threshold;
- change the 0.05 d horizon;
- change forcing;
- move the event bracket post hoc;
- introduce iterative root finding in NLGLOB14M;
- switch back to TG;
- change timestep, saturation indicators, mass gates, K staging or nonlinear policy.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14M

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14m-first-retreat-event`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: replay the fixed 8 NLGLOB14L fixtures and localize the first retreat-node h=0 bracket

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
