# F-PE-NLGLOB14Z14 result — control exposure beyond 12:16

Date: 2026-09-30

Status:

`BLOCKED_NLGLOB14Z14_CONTROL_EXPOSURE`

with preserved accepted event evidence in 1/4 fixtures.

Qualification authority:

- workflow run: `36679840835`;
- job: `109772670591`;
- workflow conclusion: SUCCESS;
- scientific aggregate: blocked by three endpoint-solve failures before four-fixture event coverage.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Does unchanged persistent-KLAG control expose exact accepted retreat:

`12:16 -> 13:16`

within the staged 300 -> 600 d horizon?

## Event exposure

One fixture accepts the exact event:

HEAD, dt = 1.25e-4 d:

- event time: `260.961125 d`;
- exact pre-state: nodes 12:16 saturated;
- exact post-state: nodes 13:16 saturated;
- complete 300 d trajectory;
- final accepted tail at 300 d: 13:16.

The accepted event is finite, contiguous, non-skipping, non-reversing and mass-clean.

## Blocking fixtures

Three fixtures terminate with `ENDPOINT_SOLVE_FAILURE` before four-fixture event exposure:

- HEAD, dt = 6.25e-5 d:
  - last observed accepted tail remains 12:16;
  - event not exposed.
- RUNOFF, dt = 1.25e-4 d:
  - last observed accepted tail remains 12:16;
  - event not exposed.
- RUNOFF, dt = 6.25e-5 d:
  - last observed accepted tail remains 11:16;
  - event not exposed.

All three remain process-return clean, finite in accepted state, geometrically consistent and mass-clean up to their accepted terminal origin.

The current Z14 aggregate does not identify the exact terminal step/time or retry-advised status; those require a separately preregistered diagnostic successor.

## Physical mass

Across all four records:

- max accepted-interval physical mass ledger: about `2.36e-14 cm`;
- max cumulative accepted ledger: about `4.09e-12 cm`.

No mass correction or redistribution occurs.

## Scientific interpretation

The physical retreat `12:16 -> 13:16` is now directly exposed in one independent control at about 260.96 d.

However, three other trajectories hit a numerical endpoint-solve boundary before full event coverage.

Therefore Z14 cannot authorize downstream split ownership.

The immediate research need is numerical attribution of the three pre-event failures, not extrapolation from the single positive trajectory.

## Direct successor

Open a separately preregistered diagnostic attribution workunit over only the three blocked fixtures.

Require per fixture:

- exact first terminal step/time;
- terminal reason;
- solver status;
- retry-advised flag if available;
- accepted saturated tail at failure origin;
- state finiteness;
- physical mass;
- dynamic-top route;
- whether failure is before or after the expected event window implied by the one positive control.

No repair is permitted inside the attribution step.

If and only if a failure is retry-advised with clean accepted state/mass, a later bounded transaction-safe subdivision successor may be opened.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
