# F-PE-NLGLOB14Z17 result — control exposure beyond 13:16

Date: 2026-09-30

Status:

`BLOCKED_NLGLOB14Z17_CONTROL_EXPOSURE`

with preserved accepted event evidence in 1/4 fixtures.

Qualification authority:

- workflow run: `36690265910`;
- jobs:
  - HEAD dt=1.25e-4: `109805546249`;
  - HEAD dt=6.25e-5: `109805546317`;
  - RUNOFF dt=1.25e-4: `109805546141`;
  - RUNOFF dt=6.25e-5: `109805545822`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Does unchanged persistent-KLAG control expose exact accepted retreat:

`13:16 -> 14:16`

within the staged 600 -> 1200 d horizon?

## Event exposure

One fixture accepts the exact event:

HEAD, dt = 1.25e-4 d:

- event time: `514.664625 d`;
- exact pre-state: nodes 13:16 saturated;
- exact post-state: nodes 14:16 saturated;
- completes 600.0 d;
- final accepted tail at 600 d: 14:16;
- no reverse, skip or geometry inconsistency;
- mass remains clean.

## Blocking fixtures

Three fixtures terminate before event exposure with:

`ENDPOINT_SOLVE_FAILURE`.

They are:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d.

Accepted terminal states remain finite, contiguous and mass-clean.

Observed final accepted tails at the terminal origin are:

- HEAD fine: 12:16;
- RUNOFF coarse: 12:16;
- RUNOFF fine: 11:16.

No target event is exposed in these three trajectories.

## Physical mass

Across the four fixture records:

- max interval physical mass ledger: about `2.36e-14 cm`;
- max cumulative accepted ledger: about `1.78e-11 cm`.

No mass correction or redistribution is used.

## Scientific interpretation

The physical retreat `13:16 -> 14:16` is directly exposed in one independent control at 514.664625 d.

The other three controls encounter a numerical endpoint-solve boundary before the target event.

Therefore Z17 cannot authorize downstream split ownership.

The immediate research question is attribution of those three pre-event failures, not extrapolation from the one positive trajectory.

## Direct successor

Open a separately preregistered three-fixture attribution workunit.

Require per blocked fixture:

- exact first terminal step/time;
- terminal reason;
- solver status;
- retry-advised flag if available;
- accepted saturated tail at failure origin;
- state finiteness;
- physical mass;
- dynamic-top route;
- whether failure is before the independently exposed target event window.

No repair is permitted in the attribution step.

Only retry-advised, state/mass-clean failures may proceed to bounded transaction-safe subdivision.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
