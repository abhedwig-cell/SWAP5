# F-PE-NLGLOB15 preregistration — physical desaturation/release semantics

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7032a7498abdec7adf879ab9ad0c05dee8049239`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;

- NLGLOB14E: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`;
- NLGLOB14D: persistent saturated KLAG mode is qualified for the frozen near-saturation horizon;
- NLGLOB12A1/NLGLOB12C: representation-aware endpoint exhaustion is qualified at research level;
- TIMEINT16C: no-event provider-consistent TG remains second order.

## Purpose

NLGLOB14E intentionally made saturated temporal mode persistent once entered.

That removes the frozen same-route endpoint blocker, but it is not yet a physical state machine suitable for production-shaped integration because no desaturation/release rule exists.

NLGLOB15 asks a narrower first question:

**can departure from persistent saturated mode be tied directly to a representably unsaturated physical state, without an empirical head or moisture threshold?**

P0 is observational first.

No production implementation is introduced.

## Frozen release quantity

Let `i_event` be the node at which the qualified saturation event was localized on entry.

At the end of every later accepted saturated-mode nominal interval define:

`Delta_theta = theta_s(i_event) - theta(i_event)`.

Define the representation scale:

`U_theta = ulp(theta_s(i_event)) + ulp(theta(i_event))`.

A state is `REPRESENTABLY_UNSATURATED` iff:

`Delta_theta > U_theta`.

No multiplicative factor above 1 is allowed.

This criterion is a state-representation test, not a numerical convergence tolerance.

## Frozen release candidate RLS0

A persistent saturated-mode state is release-eligible only if all hold:

1. the current accepted interval completed physically and transactionally;
2. the event node is `REPRESENTABLY_UNSATURATED`;
3. accepted pressure head and moisture state are finite;
4. the constitutive provider evaluated on the accepted head returns a finite state consistent with the accepted moisture to the existing roundtrip authority;
5. the dynamic-top provider route is finite and valid;
6. the accepted interval physical ledger satisfies the unchanged `5e-8 cm` gate.

RLS0 does not itself switch the temporal method in P0.

## Drying/release probe

The release question cannot be identified on a permanently wet forcing trajectory alone.

Reuse the exact five NLGLOB14D near-saturation target configurations, but extend each trajectory with a fixed drying phase after saturated-mode entry.

Frozen drying protocol:

- first, use the original target forcing until qualified saturation entry occurs;
- after the first successful event+remainder interval, set the potential surface supply term `rain` to exactly `0 cm/d` for subsequent nominal intervals;
- keep all other dynamic-top parameters, route physics, bottom boundary, dt, K staging, tolerances, S0/R0 endpoint certificates and transaction semantics unchanged;
- extend the horizon to exactly `0.004 d`, unless the original dt does not divide that horizon, in which case the case is invalid and coverage fails.

No negative rainfall, artificial evaporation pulse or fitted release forcing is allowed.

## P0 observational diagnostics

For every accepted saturated-mode interval after drying begins, record:

- step index;
- event node;
- accepted `theta`;
- `theta_s`;
- `Delta_theta`;
- `U_theta`;
- ratio `R_unsat = Delta_theta / max(U_theta,tiny)`;
- accepted pressure head at the event node;
- dynamic-top route;
- interval physical ledger;
- whether RLS0 is true.

Also record whether a trajectory that becomes RLS0-eligible remains representably unsaturated for the next accepted interval.

## Frozen P0 classifications

If at least 4/5 trajectories:

- become RLS0-eligible during the drying phase;
- do so with finite, route-consistent, mass-clean accepted states;
- and remain representably unsaturated on the next accepted interval,

classify:

`NLGLOB15_REPRESENTATIONAL_RELEASE_SIGNAL`.

If 0/5 or 1/5 ever become RLS0-eligible:

`NLGLOB15_NO_RELEASE_SIGNAL`.

Otherwise:

`NLGLOB15_MIXED_RELEASE_SIGNAL`.

Any mass, nonfinite or route-state defect in an RLS0-eligible state classifies:

`NLGLOB15_RELEASE_SIGNAL_UNSAFE`.

If drying coverage cannot be executed faithfully:

`BLOCKED_NLGLOB15_RELEASE_COVERAGE`.

## Positive consequence

A positive P0 result authorizes a separately preregistered P1 test-only state-machine replay:

- `SATURATED_KLAG -> UNSATURATED_TG` only at an accepted interval boundary satisfying RLS0;
- the first released interval must start physically from that accepted committed state;
- no hidden trial state may leak across the switch;
- subsequent TG execution must retain the existing saturation-event entry logic;
- re-entry into saturated mode remains allowed only through the already qualified saturation event contract.

P1 must then qualify full mass, state, route and no-event smooth-order behavior.

## Stop rules

Do not introduce after outcome exposure:

- a multiplier on `U_theta`;
- a fixed head threshold;
- a fixed moisture deficit threshold;
- hysteresis width;
- minimum saturated-mode duration;
- release based on iteration count;
- release based only on top-boundary route;
- tolerance relaxation.

A materially different release rule requires separate preregistration.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

Expected P0 effect: diagnostic only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB15

BASELINE: `7032a7498abdec7adf879ab9ad0c05dee8049239`

BRANCH: `research/f-pe-nlglob15-desaturation-release-current`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize zero-supply drying phase and observational RLS0 diagnostics on the five frozen saturation-entry targets

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
