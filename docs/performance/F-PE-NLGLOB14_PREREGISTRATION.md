# F-PE-NLGLOB14 preregistration — saturation-boundary temporal-event formulation

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7ea6fc05ef589e3adb3e26ef1d436e514604197f`

Parent authority:

- TIMEINT16C: provider-consistent endpoint TG staging is second order on the smooth bank;
- NLGLOB11A: head-space endpoint coefficient staging preserves smooth second order but does not remove the near-saturation accepted-state defect;
- NLGLOB13C2: same-origin temporal refinement contracts the accepted-state overshoot;
- NLGLOB13D: bounded subdivision through h/8 is insufficient for the five remaining targets.

## Purpose

The near-saturation defect is now treated as a temporal event problem rather than as a timestep-depth problem.

NLGLOB14 asks whether the first prospective crossing of the constitutive saturation boundary can be represented as an explicit within-interval event and localized from the temporal method itself, without clipping accepted moisture.

P0 is formulation/attribution first.

No production code or production acceptance rule changes.

## Frozen target set

Use the five NLGLOB13D targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

The two NLGLOB13C2 h/4-admissible trajectories are retained as comparator cases but are not primary targets.

## Event definition

At an accepted physical origin `(theta_n,h_n)`, evaluate the unchanged head-space/provider-consistent TG construction over the full prospective interval `h` far enough to obtain the prospective accepted moisture vector:

`theta_TG^*(h)`.

No prospective state is committed.

For each node with:

`theta_TG,i^*(h) > theta_s,i`

and

`theta_TG,i^*(h) > theta_n,i`

define the linear temporal crossing estimate:

`phi_i = (theta_s,i - theta_n,i) / (theta_TG,i^*(h) - theta_n,i)`.

Define the first candidate saturation event fraction:

`phi_sat = min_i phi_i`

over crossing nodes.

Frozen validity requirements:

- `0 < phi_sat < 1`;
- all quantities finite;
- the selected crossing node is recorded;
- accepted origin is strictly retention-admissible;
- no accepted state is clipped.

This `phi_sat` is an event-time estimate, not an accepted-state modification.

## P0 — event-localization probe

From the exact same accepted origin, execute one test-only TG trial with:

`h_event = phi_sat * h`.

The trial uses:

- unchanged head-space endpoint coefficient staging;
- unchanged TG accepted update;
- unchanged S0/R0 research endpoint certificates;
- unchanged physical mass ledger;
- unchanged route physics.

The event trial is not followed by the remainder interval in P0.

Record:

1. selected crossing node;
2. `phi_sat`;
3. event-trial accepted `theta_event`;
4. signed saturation distance at selected node:
   `d_sat = theta_s - theta_event`;
5. maximum accepted-state domain overshoot, if any;
6. route before and after the event trial;
7. ponding state;
8. physical interval ledger;
9. finite-state status.

## Frozen event-localization gates

Classify:

`NLGLOB14_SATURATION_EVENT_LOCALIZATION_QUALIFIED`

only if all five primary targets satisfy:

1. valid finite `0 < phi_sat < 1`;
2. event trial executes without process failure;
3. event accepted state has no node above `theta_s`;
4. selected-node event state is within `5e-8 cm / dz_selected` equivalent water-content distance of saturation;
5. event trial physical ledger <= `5e-8 cm`;
6. no nonfinite state;
7. route transition, if any, is explicit and consistent with the dynamic-top provider.

The water-content event-distance gate is derived from the existing physical water-depth authority:

`|theta_s-theta_event| * dz_selected <= 5e-8 cm`.

No fitted theta tolerance is introduced.

If at least 3/5 event trials remain retention-inadmissible:

`NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT`.

If event trials remain admissible but fewer than 3/5 reach the physical event-distance gate:

`NLGLOB14_EVENT_TIME_ESTIMATE_NOT_LOCALIZED`.

If route/nonfinite/mass safety fails:

`NLGLOB14_EVENT_LOCALIZATION_PHYSICAL_ADMISSIBILITY_FAILED`.

If coverage fails:

`BLOCKED_NLGLOB14_EVENT_LOCALIZATION_COVERAGE`.

## P1 — conservative event split

P1 is authorized only after positive P0.

P1 must be separately preregistered before outcome exposure.

It must:

1. integrate to the qualified saturation event;
2. commit that admissible subinterval transactionally;
3. reevaluate the dynamic-top/saturated route from the event state;
4. integrate the remaining `(1-phi_sat)h` interval under the explicitly resolved route;
5. preserve the full nominal-interval physical mass ledger;
6. preserve smooth second-order authority when no event occurs.

No accepted-theta clipping is allowed.

## Stop rules

NLGLOB14 P0 does not authorize:

- h/16 or deeper subdivision;
- recursive timestep halving;
- accepted-state clipping;
- constitutive extrapolation beyond saturation;
- empirical event-fraction damping;
- tolerance relaxation;
- production integration.

If the linear event estimate fails P0, the successor must change the event-time formulation, not tune `phi_sat` post hoc.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

Expected effect in P0: observational/test-only temporal-event attribution.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14

BASELINE: `3b1488c0d2723f9ec02709693406b4ecb45377ea`

BRANCH: `research/f-pe-nlglob14-saturation-event-current`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize prospective TG event diagnostics and execute P0 on the frozen five-target bank

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
