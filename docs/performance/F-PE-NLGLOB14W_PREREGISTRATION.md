# F-PE-NLGLOB14W preregistration — split accepted-state second-retreat ownership transition

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14T: one coupled transactional split shadow interval qualified;
- NLGLOB14U: bounded multi-interval split accepted-state persistence qualified, but no second retreat occurred within 0.05 d;
- NLGLOB14V: `QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`, with persistent-KLAG accepted geometry `4:16 -> 5:16` near 0.106 d.

## Purpose

Test the first actual moving-interface ownership transition.

Question:

can the private split accepted-state trajectory, without being told the control event time, carry the accepted saturated set from nodes 4:16 to nodes 5:16 and thereby move the single ownership face from 3/4 to 4/5 while preserving transaction, mass and no-chatter semantics?

## Frozen fixtures

Use O05:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- start from each fixture's qualified first-retreat accepted state;
- unchanged dry forcing and qbot;
- split accepted-state evolution generalized from NLGLOB14U;
- horizon = 0.12 d, chosen before result exposure because NLGLOB14V independently locates the control second retreat near 0.106 d.

The split trajectory must not use the NLGLOB14V event time as a switch, root, threshold or initial guess.

## Ownership rule

At each accepted split origin:

- derive the saturated set from that accepted split physical state;
- require a contiguous lower block `k:16`;
- upper nodes `1:k-1` are TG-owned;
- lower nodes `k:16` are saturated/full-Richards-owned;
- the unique interface face is `k-1/k`;
- one time-integrated physical interface exchange closes both subdomain balances.

After candidate acceptance, recompute `k` from the accepted physical state.

A genuine second-retreat ownership transition is:

- accepted state before: saturated nodes 4:16, face 3/4;
- accepted state after: saturated nodes 5:16, face 4/5 on the next interval.

No other trigger is allowed.

## Transaction and numerical contract

Use the already-qualified NLGLOB14U private accepted-state pattern.

Each candidate:

1. begins from immutable accepted split state;
2. solves the coupled split residual;
3. must satisfy finite-state, residual and mass gates;
4. is accepted only after those gates;
5. otherwise rolls back exactly and the fixture stops.

No retry/tolerance tuning is introduced.

## Frozen positive gate per fixture

A fixture classifies `SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION` only if:

1. at least one accepted split interval exists before the transition;
2. the accepted split state exhibits exact contiguous `4:16 -> 5:16`;
3. the ownership face changes correspondingly from 3/4 to 4/5;
4. the transition is state-derived, not time-triggered;
5. no prior or later reverse `5:16 -> 4:16` move occurs through 0.12 d;
6. no ownership chatter occurs;
7. no noncontiguous saturated set occurs;
8. no upper TG saturation re-entry occurs;
9. max interval mass ledger <= 5e-8 cm;
10. cumulative ledger <= 5e-8 cm;
11. max residual <= 1e-10;
12. rollback differences remain <= 1e-15 for any rejected candidate.

Record the split transition time and compare it to the NLGLOB14V control event only after the split transition has been independently identified.

No frozen timing-identity tolerance is imposed in this first transition workunit. Timing difference is diagnostic, not a pass condition.

## Frozen failure classifications

If all interval mechanics remain valid but no split 4:16 -> 5:16 transition occurs by 0.12 d:

`NLGLOB14W_SPLIT_SECOND_RETREAT_NOT_EXPOSED`.

If interface reverses or alternates:

`NLGLOB14W_INTERFACE_CHATTER`.

If accepted geometry becomes noncontiguous:

`NLGLOB14W_NONCONTIGUOUS_SATURATED_SET`.

If upper TG ownership re-enters saturation:

`NLGLOB14W_UPPER_TG_OWNERSHIP_NOT_PERSISTENT`.

If mass, rollback or accepted-state accounting leaks:

`NLGLOB14W_TRANSACTION_INCONSISTENT`.

If the coupled interface ceases to close:

`NLGLOB14W_INTERFACE_COUPLING_NOT_PERSISTENT`.

Otherwise mixed outcomes classify `NLGLOB14W_MIXED_SECOND_RETREAT_TRANSITION`.

## Frozen aggregate positive classification

Only if all 8 fixtures classify `SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION_RESEARCH`.

## Interpretation boundary

A positive result qualifies the first observed ownership-face motion only.

It does not yet qualify:

- repeated multiple face transitions;
- full saturated-block disappearance;
- switch to whole-column TG;
- broad materials/forcing;
- production temporal ownership.

## Stop rules

Do not:

- prescribe 0.106 d as the split transition;
- fit h/theta/count thresholds;
- add hysteresis;
- introduce independent interface fluxes;
- redistribute residual mass;
- alter forcing or solver tolerances;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14W

BASELINE: `c08cf9c29b8468530befffc02e1345d7822a58ba`

BRANCH: `research/f-pe-nlglob14w-split-second-retreat-transition`

NEXT SAFE STEP: run the qualified accepted split formulation to 0.12 d on the 8-fixture bank and classify the first actual ownership-face transition.

## Production boundary

Research only. `LEGACY_NUMERICS` remains production default.
