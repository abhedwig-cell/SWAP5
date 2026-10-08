# F-PE-NLGLOB14S preregistration — moving-interface split temporal ownership feasibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b1ab94eb2940203f3a4564d72383247d71bb4fad`

Parent research authority:

- NLGLOB14N3: refined first-retreat event timing qualified;
- NLGLOB14Q: one full-column TG shadow interval at first retreat admissible;
- NLGLOB14R1/R2/R3: persistent full-column TG continuation requires repeated retry and yields no accepted post-handoff progress within bounded retry authority;
- NLGLOB14R4: `NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`;
- whole-column first-retreat release is therefore falsified as a stable ownership rule under the current formulation.

## Purpose

NLGLOB14S begins a different ownership formulation rather than repairing the falsified whole-column release route.

Question:

at the qualified first-retreat state, is a spatially split temporal ownership decomposition mechanically feasible in which:

- the unsaturated upper domain is TG-owned;
- the persistent contiguous lower saturated block retains saturated temporal treatment;
- exactly one physical interface flux couples the two domains;
- total water and accepted-state authority remain single-valued?

This first workunit is observational only.

No split solver and no mode switch are implemented.

## Frozen fixtures

Use the same 12 O05 first-retreat states:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- first accepted 14 -> 13 retreat endpoint;
- current saturated set = nodes 4:16;
- unsaturated upper set = nodes 1:3;
- unchanged dry forcing;
- unchanged NLGLOB14N3 saturation-entry policy;
- persistent KLAG trajectory remains control authority.

## Frozen split interface

The ownership interface is fixed by the accepted state, not by a fitted depth:

- upper TG domain: nodes 1:3;
- lower saturated domain: nodes 4:16;
- interface face: between nodes 3 and 4.

Define the physical interface flux from the accepted state using the existing hydraulic convention and provider:

`q_3.5 = -Kmean * ((h_3-h_4)/distance + 1)`.

Exactly the same signed `q_3.5` must be used:

- as lower boundary flux of the upper domain;
- as upper boundary flux of the lower domain.

No independent interface flux may be fitted for either side.

## Frozen observational decomposition

At each first-retreat accepted state compute:

1. accepted full-profile physical moisture derivative from top flux, internal fluxes and qbot;
2. upper-domain derivative for nodes 1:3 using the accepted top flux and shared q_3.5;
3. lower-domain derivative for nodes 4:16 using shared q_3.5 and qbot;
4. upper-domain TG head-space predictor using existing provider C on nodes 1:3 only;
5. lower-domain storage tendency from the same physical flux divergence without converting saturated lower nodes to full-column TG head-space prediction.

## Frozen feasibility gates

A fixture is `SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE` only if all hold:

1. accepted saturated set is exactly contiguous nodes 4:16;
2. upper nodes 1:3 are unsaturated and have finite positive provider capacity;
3. shared interface flux is finite;
4. upper-domain theta_dot is finite;
5. lower-domain theta_dot is finite;
6. upper TG h_dot and h_tilde are finite;
7. upper predicted conductivity is finite and >0;
8. sum of independently reconstructed upper and lower storage tendencies equals the full-profile storage tendency to `1e-12 cm/d`;
9. interface cancellation is exact to `1e-12 cm/d`;
10. control trajectory remains finite and mass-clean.

If the shared interface cannot close the two domain balances, classify `SPLIT_INTERFACE_MASS_INCONSISTENT`.

If upper TG predictor is inadmissible, classify `UPPER_TG_DOMAIN_INADMISSIBLE`.

If accepted saturated-set geometry is not the frozen 3/13 split, classify `SPLIT_GEOMETRY_NOT_APPLICABLE`.

## Frozen aggregate interpretation

If 12/12 classify `SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`:

`NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`.

If any interface mass inconsistency occurs:

`NLGLOB14S_SPLIT_INTERFACE_MASS_INCONSISTENT`.

If any upper-domain TG inadmissibility occurs:

`NLGLOB14S_UPPER_TG_DOMAIN_INADMISSIBLE`.

Otherwise:

`NLGLOB14S_MIXED_SPLIT_FEASIBILITY`.

## Interpretation boundary

A positive result establishes only that the accepted state admits a conservative spatial decomposition with one shared interface flux and a valid upper TG predictor.

It does not establish:

- a coupled split-domain endpoint solve;
- a unique interface-head condition;
- stable movement of the interface;
- production temporal ownership.

Those require separately preregistered successors.

## Stop rules

Do not:

- modify the accepted trajectory;
- solve upper and lower domains independently;
- introduce an interface-head fit;
- introduce a release threshold or hysteresis;
- change retry policy, capacity regularization, forcing, dt or mass gates;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: observational decomposition only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14S

BASELINE: `b1ab94eb2940203f3a4564d72383247d71bb4fad`

BRANCH: `research/f-pe-nlglob14s-split-ownership-feasibility`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: reconstruct the shared 3/4 interface flux and separate upper/lower storage tendencies on the 12 qualified first-retreat accepted states.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
