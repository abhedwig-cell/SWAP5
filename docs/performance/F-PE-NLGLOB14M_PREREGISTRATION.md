# F-PE-NLGLOB14M preregistration — first saturated-block retreat event bracket

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Parent authority:

- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`;
- NLGLOB14L: `NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`;
- all eight NLGLOB14L fixtures show partial retreat after a 14-node saturated-block peak.

## Purpose

NLGLOB14M identifies the first physically explicit retreat event before attempting event-time root localization or a temporal-mode release switch.

The first phase is observational only.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14L fixtures:

- O05/TG;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.05 d;
- unchanged dry forcing, persistent saturated-KLAG mode, S0/R0 certificates and mass authority.

## Frozen retreat event

For each fixture:

1. determine the attained maximum saturated-node count;
2. let state L be the last accepted state at that maximum before the first later decline;
3. let state R be the first accepted state with saturated-node count below that maximum;
4. require R to be the immediately following accepted nominal state.

The event node is the shallowest node that is saturated in L and unsaturated in R.

## Frozen physical bracket contract

A valid first-retreat bracket requires:

1. maximum saturated count = 14;
2. R count = 13;
3. event node is identical across all dt levels within a route family;
4. saturated set is contiguous in L and R;
5. at the event node:
   - L has `SAT_H=1` and `SAT_THETA=1`;
   - R has `SAT_H=0` and `SAT_THETA=0`;
   - `h_L >= 0`;
   - `h_R < 0`;
   - `theta_L = theta_s`;
   - `theta_R < theta_s`;
6. all other nodes preserve head/moisture saturation-indicator consistency;
7. both accepted states are finite and mass-clean.

No threshold around h=0 or theta_s is introduced.

## Frozen time bracket

Define:

`[t_L,t_R]`

from accepted-state times.

The bracket width must equal exactly one nominal dt within floating-point time authority.

Define the observational midpoint:

`t_mid = 0.5*(t_L+t_R)`.

No linear state interpolation is accepted as a physical event state in NLGLOB14M.

## Frozen dt-consistency gates

For each route family separately:

1. all four dt levels provide a valid bracket at the same event node;
2. bracket width halves with dt refinement;
3. the finest two midpoint estimates differ by no more than:
   `4 * dt_finest`;
4. the finest bracket lies within the envelope:
   `[min(t_L across all dt), max(t_R across all dt)]`.

The factor 4 is frozen before NLGLOB14M result exposure as a discretization-consistency bound, not a physical threshold.

## Frozen classifications

If both HEAD and RUNOFF families pass all gates:

`NLGLOB14M_RETREAT_EVENT_BRACKET_QUALIFIED`.

If event nodes differ across dt or route within a family:

`NLGLOB14M_RETREAT_EVENT_NODE_INCONSISTENT`.

If physical state indicators fail:

`NLGLOB14M_RETREAT_EVENT_STATE_INCONSISTENT`.

If brackets are valid but dt-consistency gates fail:

`NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`.

If coverage fails:

`BLOCKED_NLGLOB14M_RETREAT_EVENT_COVERAGE`.

## Positive consequence

A positive bracket result authorizes a separately preregistered NLGLOB14N bracket-preserving root localization of the event function at the identified event node.

No release switch is authorized by NLGLOB14M.

## Stop rules

Do not:

- change the event node after result exposure;
- add pressure/moisture thresholds;
- interpolate and commit an event state;
- alter horizon, forcing, dt levels or temporal policy;
- switch back to TG.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14M

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14m-retreat-event-bracket`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: extract first-retreat state brackets from the frozen 8 fixtures

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
