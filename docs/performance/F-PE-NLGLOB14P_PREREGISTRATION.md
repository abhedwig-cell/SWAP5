# F-PE-NLGLOB14P preregistration — first-retreat full-column TG predictor admissibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14N3: `QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`;
- restored NLGLOB14N: `QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`;
- NLGLOB14O: `NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE` under the existing dt-dependent provider capacity contract.

## Purpose

NLGLOB14O showed that the first-retreat state has positive provider capacity on every active node, but saturated nodes obtain that positivity from the existing B1.10 regularization:

`C = dt * 1e-7`.

NLGLOB14P asks whether the currently qualified head-space TG predictor itself remains admissible over the full column at that state.

No TG solve and no mode switch are performed.

## Frozen fixtures

Use the same 12 six-level O05 trajectories:

- HEAD and RUNOFF route families;
- dt = 2.5e-4 through 7.8125e-6 d;
- horizon = 0.05 d;
- NLGLOB14N3 root-controller policy;
- persistent saturated KLAG remains the accepted trajectory;
- unchanged dry forcing and physical mass authority.

## Frozen handoff origin

Use the same RETREAT_HANDOFF_ORIGIN from NLGLOB14O:

- node 3 first unsaturated accepted post-retreat state;
- nodes 4:16 remain saturated;
- contiguous saturated lower block;
- finite, mass-clean accepted state.

## Frozen physical moisture derivative

At the accepted handoff origin:

1. evaluate node conductivities from the same O05 constitutive provider;
2. use the accepted dry-phase top flux from the accepted state diagnostics;
3. use the unchanged zero bottom flux;
4. construct each internal interface flux with the existing SWAP convention;
5. derive `theta_dot` from flux divergence over the frozen 10 cm cells.

No derivative is reconstructed from storage changes.

## Frozen head-space predictor

Use the existing provider capacity C at the handoff origin and form:

`h_dot_i = theta_dot_i / C_i`

`h_tilde_i = h_i + dt * h_dot_i`.

The full-column predictor is admissible only if for all 16 nodes:

- C is finite and >0;
- theta_dot is finite;
- h_dot is finite;
- h_tilde is finite;
- conductivity evaluated at h_tilde is finite and >0.

This is the existing NLGLOB11A/TIMEINT16C head-space predictor criterion, applied to the full retreat-origin profile.

No magnitude threshold for h_tilde is introduced.

## Frozen diagnostics

For every fixture record:

- max |h_dot|;
- min/max h_tilde;
- node of max |h_dot|;
- minimum predicted conductivity;
- whether the worst node lies in the still-saturated lower block;
- physical mass of the accepted control trajectory.

## Frozen classifications

If all 12 full-column predictors satisfy every frozen admissibility condition:

`NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`.

If all 12 fail and the failing node is in the still-saturated lower block:

`NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_FALSIFIED_BY_LOWER_BLOCK`.

If predictor validity is route/dt dependent:

`NLGLOB14P_MIXED_FULL_COLUMN_TG_PREDICTOR`.

If accepted-state, mass or constitutive consistency fails:

`NLGLOB14P_PREDICTOR_STATE_INCONSISTENT`.

## Consequence

A positive result may justify a separately preregistered transactional shadow TG solve from the retreat origin under the actual dry forcing.

A negative result closes whole-column TG handoff at first retreat and redirects mode ownership toward moving-interface/split-domain treatment or later complete desaturation.

## Stop rules

Do not:

- run or accept a TG solve;
- switch mode;
- change provider capacity;
- add a capacity floor;
- clip h_dot or h_tilde;
- change forcing, dt, horizon or event definition;
- relax mass gates.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14P

BRANCH: `research/f-pe-nlglob14p-full-column-tg-predictor`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: compute the full-column head-space predictor at the 12 qualified retreat origins.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
