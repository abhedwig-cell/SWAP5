# F-PE-NLGLOB12A result — aggregate storage-representation floor attribution

Date: 2026-09-29

Status:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`

Qualification authority:

- workflow run: `36553184850`;
- job: `109356012043`;
- conclusion: SUCCESS.

## Frozen question

Are the eight NLGLOB12 above-floor stagnation trajectories already bounded by the arithmetic representation scale of their stored moisture differences, despite remaining above the existing scalar balance gate?

No solver behavior was changed.

## Coverage

PASS.

Exactly the frozen 8 stagnation trajectories were reproduced.

- process failures: 0;
- finite/route/head/ponding guards: 8/8.

## Representation result

All eight terminal stagnation states satisfy both preregistered representation bounds:

- `R_total_ulp <= 1`: 8/8;
- `R_local_ulp <= 1`: 8/8;
- both bounds plus existing guards: 8/8.

Frozen classification:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`.

## Interpretation

The residual plateau in these eight cases is not merely “small”.

At terminal stagnation, both the aggregate total residual and the largest local residual are no larger than the arithmetic representation scale implied by the stored `theta - theta_m1` differences themselves.

This strengthens the NLGLOB04 storage-floor attribution from a dominant-node observation to a full endpoint-state representation statement for the stagnation subset.

The current BALTOL02 authority is not changed.

## Consequence

A separately preregistered representation-aware convergence certificate may now be tested.

Such a certificate must derive its acceptance from:

- existing head and ponding guards;
- route/finite-state validity;
- `R_total_ulp <= 1`;
- `R_local_ulp <= 1`;
- unchanged physical accepted-interval mass closure.

It must not introduce an empirically enlarged scalar balance tolerance.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No BALTOL02, mass, MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
