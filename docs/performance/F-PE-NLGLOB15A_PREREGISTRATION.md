# F-PE-NLGLOB15A preregistration — route-flexible drying/release attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Parent authority:

- NLGLOB14E1: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`;
- NLGLOB14F: no natural release occurs in the original frozen wet horizon;
- NLGLOB15: zero-supply drying probe is blocked by inherited same-route termination;
- NLGLOB15 release quantity RLS0 remains unmodified.

## Purpose

NLGLOB15A obtains faithful drying-phase coverage by allowing the existing dynamic-top provider to change route after saturation entry without terminating the research driver solely because the provider route differs from the initial fixture route.

This workunit is observational only.

Persistent saturated KLAG mode remains active throughout the drying horizon.

No switch back to TG is performed.

## Frozen population and forcing

Reuse exactly the five NLGLOB15 cases:

- O05 / initial HEAD / dt = 0.00025 d;
- O05 / initial HEAD / dt = 0.000125 d;
- O05 / initial HEAD / dt = 0.0000625 d;
- O05 / initial RUNOFF / dt = 0.00025 d;
- O05 / initial RUNOFF / dt = 0.000125 d.

Use the exact NLGLOB15 forcing protocol:

1. original wet forcing until qualified saturation entry;
2. after successful saturation entry, set `rain = 0 cm/d`;
3. extend to horizon `0.004 d`;
4. keep all other dynamic-top parameters, bottom boundary, dt, K staging, S0/R0 certificates, tolerances and transaction semantics unchanged.

## Route-flexible diagnostic execution

The original same-route test driver contains guards that terminate when the dynamic-top provider selects a route different from the initial fixture route.

For persistent saturated-mode intervals only, NLGLOB15A disables those **test-driver route-equality termination guards**.

It does not override or select a route.

The dynamic-top provider remains sole route authority.

Requirements:

- before saturation entry, the original same-route guards remain unchanged;
- after entry, the provider-selected origin and endpoint route codes are accepted if valid;
- route changes are logged explicitly;
- provider unavailable, invalid or nonfinite route remains fail-closed;
- the physical equations and provider evaluation are unchanged.

## Frozen release quantity

Retain NLGLOB15 unchanged.

At event node `i_event` after every accepted drying-phase interval:

`Delta_theta = theta_s(i_event) - theta(i_event)`

`U_theta = ulp(theta_s(i_event)) + ulp(theta(i_event))`

`REPRESENTABLY_UNSATURATED = (Delta_theta > U_theta)`.

No multiplier above one is allowed.

## Frozen release candidate RLS0

A state is release-eligible only when all hold:

1. interval accepted transactionally;
2. event node is representably unsaturated;
3. accepted state is finite;
4. accepted head/moisture constitutive state remains consistent with existing authority;
5. provider-selected route is valid;
6. physical interval ledger <= `5e-8 cm`.

No temporal-method switch occurs in NLGLOB15A.

## Diagnostics

For each persistent saturated-mode drying interval record:

- step;
- event node;
- accepted theta and theta_s;
- Delta_theta and U_theta;
- R_unsat;
- accepted event-node pressure head;
- provider origin route;
- provider endpoint route;
- whether the route changed in the interval;
- interval physical ledger;
- RLS0 state.

Also record whether an RLS0-positive state remains representably unsaturated on the next accepted interval.

## Frozen coverage gate

Coverage requires all five:

- enter saturated mode;
- execute through the full `0.004 d` horizon;
- have no process failure;
- remain finite and mass-clean;
- record valid provider route codes after entry.

If not:

`BLOCKED_NLGLOB15A_ROUTE_FLEX_RELEASE_COVERAGE`.

## Frozen classifications

If >=4/5 trajectories:

- become RLS0-eligible;
- do so with finite, route-valid, mass-clean state;
- remain representably unsaturated on the next accepted interval,

classify:

`NLGLOB15A_REPRESENTATIONAL_RELEASE_SIGNAL`.

If 0/5 or 1/5 become persistent RLS0-positive after full coverage:

`NLGLOB15A_NO_RELEASE_SIGNAL`.

Otherwise:

`NLGLOB15A_MIXED_RELEASE_SIGNAL`.

Any mass/nonfinite/provider-route defect in an RLS0-positive state:

`NLGLOB15A_RELEASE_SIGNAL_UNSAFE`.

## Positive consequence

A positive result authorizes a separately preregistered test-only state-machine replay:

`SATURATED_KLAG -> UNSATURATED_TG`

only at an accepted interval boundary satisfying unchanged RLS0.

Re-entry to saturation remains allowed only through the already qualified saturation-event contract.

## Stop rules

Do not introduce:

- fixed head threshold;
- fixed moisture deficit threshold;
- ULP multiplier;
- hysteresis band;
- minimum residence time;
- route-based release;
- altered provider route logic;
- tolerance or timestep change.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB15A

BASELINE: `e46985908b19f83cf2f17f86507aa3495df971a2`

BRANCH: `research/f-pe-nlglob15a-route-flex-release`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize route-flexible persistent-mode diagnostics and rerun exact NLGLOB15 drying cases

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
