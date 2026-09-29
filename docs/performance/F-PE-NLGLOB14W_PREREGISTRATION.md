# F-PE-NLGLOB14W preregistration — split ownership transition across second retreat

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14T: `QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`;
- NLGLOB14U: repeated accepted split evolution is conservative and chatter-free through the existing bounded post-retreat horizon, while actual interface motion was not exercised there;
- NLGLOB14V: `QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`;
- persistent-KLAG control exposes exact accepted saturated-set transition `4:16 -> 5:16` near 0.106 d;
- no reverse move and no noncontiguous control geometry occur.

## Frozen question

Can the accepted split trajectory independently cross the second physical lower-edge retreat and move temporal-ownership face:

`3/4 -> 4/5`

only because its own accepted saturated set changes:

`4:16 -> 5:16`

while preserving one interface authority, physical mass, transaction semantics and no chatter?

The control event time is a comparator only. It is not prescribed to the split trajectory.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- horizon = `0.12 d`, fixed before exposure;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero qbot;
- first-retreat accepted state as split-sequence origin;
- persistent-KLAG run over the same horizon solely as matched comparator and event-time authority.

The 0.12 d horizon is selected because NLGLOB14V independently exposed all second-retreat events near 0.106 d. It is not selected from split behavior.

## Dynamic-top contract

The split trajectory must not replay the control top-flux sequence.

For every research interval, reconstruct the existing dry unponded B110 dynamic-top semantics from the split accepted state:

- frozen potential bare/pond evaporation demand equals the original wet forcing magnitude;
- precipitation, irrigation, snowmelt and runon remain zero;
- SWKIMPL=0 top-node conductivity is fixed at the accepted interval origin during candidate evaluation;
- atmospheric hydraulic evaporation capacity is recomputed from the candidate top head;
- the physical top flux follows the provider's unponded surface-flux/atmospheric-head law.

Any need for a ponded/runoff branch in this frozen drying sequence is a provider-semantics failure for this workunit, not a parameter to fit.

## Accepted-state ownership rule

At every accepted origin:

1. identify the maximal contiguous saturated set ending at node 16 using the physical accepted state;
2. all nodes above it are TG-owned;
3. the lower set is saturated-owned;
4. the single ownership face lies immediately above the lower set;
5. candidate ownership is not changed inside Newton;
6. after candidate acceptance, recompute ownership from the new accepted physical state.

A 3/4 -> 4/5 move is valid only if the newly accepted state itself is exactly `5:16` saturated.

No h threshold, theta epsilon for release, fitted event time, count-only heuristic or hysteresis is allowed.

## Interval formulation

Use the NLGLOB14T/U split residual:

- one coupled full-profile endpoint head vector;
- upper TG/trapezoidal physical storage treatment;
- lower saturated/full-Richards endpoint treatment;
- one Darcy flux per face;
- one shared trapezoidal temporal exchange integral at the ownership face, used with opposite signs in the two domain balances;
- provider-faithful origin/endpoint top exchange;
- zero bottom flux;
- no residual redistribution.

## Transaction contract

Each research interval is transactional.

A candidate is committed only if all finite-state, residual, mass, geometry and ownership gates pass.

Rejected candidates leave the previous private accepted state exactly unchanged.

The persistent-KLAG control trajectory is never mutated.

## Required diagnostics

Per fixture record:

- split first-retreat origin time;
- split second-retreat accepted time, if any;
- control second-retreat accepted time;
- pre/post split saturated sets;
- pre/post ownership faces;
- event-time difference split minus control;
- interface flux origin/endpoint/integral across the transition interval;
- physical mass ledger and cumulative ledger;
- nonlinear iterations/residual;
- top-provider route;
- noncontiguous states;
- reverse 4/5 -> 3/4 motion after transition;
- rejected candidate rollback;
- matched control head/theta differences.

## Frozen gates

A fixture qualifies `SPLIT_SECOND_RETREAT_TRANSITION_VALID` only if:

1. it reaches at least the accepted second-retreat event or the 0.12 d horizon;
2. all accepted intervals are finite;
3. max node residual <= `1e-10`;
4. max absolute interval and cumulative physical mass ledger <= `5e-8 cm`;
5. no independent interface exchange exists;
6. split saturated geometry remains contiguous;
7. the first forward ownership move is exactly face 3/4 -> 4/5;
8. that move occurs only on an accepted state with saturated set exactly 5:16;
9. there is no reverse 4/5 -> 3/4 move afterward;
10. top-boundary semantics remain on the admitted dry unponded provider law;
11. rollback differences after any rejected trial remain <= `1e-15`.

Event-time agreement with persistent KLAG is diagnostic, not an identity gate.

## Frozen classifications

If all 8 fixtures satisfy the transition gate:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`.

If split trajectories remain valid to 0.12 d but some/all do not reach 5:16:

`NLGLOB14W_SPLIT_SECOND_RETREAT_NOT_REACHED`.

If the ownership face oscillates or reverses after a valid transition:

`NLGLOB14W_INTERFACE_CHATTER_AT_SECOND_RETREAT`.

If accepted saturated geometry becomes noncontiguous:

`NLGLOB14W_SECOND_RETREAT_GEOMETRY_INCONSISTENT`.

If coupled solve cannot progress through the event while rollback remains clean:

`NLGLOB14W_SECOND_RETREAT_COUPLING_NOT_CLOSED`.

If mass, rollback or state authority leaks:

`NLGLOB14W_SECOND_RETREAT_TRANSACTION_INCONSISTENT`.

If reconstructed top-boundary semantics leave the frozen dry provider profile:

`NLGLOB14W_DYNAMIC_TOP_NOT_PRESERVED`.

Mixed otherwise-valid outcomes:

`NLGLOB14W_MIXED_SECOND_RETREAT_TRANSITION`.

## Consequence boundary

A positive NLGLOB14W result qualifies actual state-driven moving-interface motion for one physical retreat event.

It does not yet qualify:

- arbitrary repeated interface migrations;
- saturated-block disappearance;
- whole-column TG re-entry;
- production ownership policy.

Those require successors.

## Stop rules

Do not:

- impose the control event time on the split solver;
- fit h/theta thresholds;
- replay control top fluxes;
- alter dry forcing;
- tune tolerances to force the transition;
- freeze lower heads;
- duplicate interface flux authority;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14W

BASELINE: `c08cf9c29b8468530befffc02e1345d7822a58ba`

BRANCH: `research/f-pe-nlglob14w-split-second-retreat`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement the provider-faithful split accepted-state sequence through the independently exposed second-retreat window.

## Production boundary

Research only. No production source or default policy changes.
