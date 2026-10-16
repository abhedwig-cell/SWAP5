# F-PE-NLGLOB12A result — aggregate storage-representation floor attribution

Date: 2026-09-29

Status:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`

Qualification authority:

- workflow run: `36552997339`;
- job: `109355404628`;
- conclusion: SUCCESS.

## Frozen question

Are the eight NLGLOB12 stagnation cases already bounded by the arithmetic representation scale implied by the stored moisture differences, even though the existing scalar balance gate remains slightly above threshold?

No convergence decision was changed.

## Coverage

PASS.

All 8/8 preregistered stagnation trajectories were reproduced.

No process failures occurred.

## Representation-floor result

All 8/8 terminal states satisfy both frozen representation bounds:

- aggregate total residual:
  `R_total_ulp <= 1`;
- maximum local residual:
  `R_local_ulp <= 1`.

Observed maxima:

- max `R_total_ulp = 0.210625`;
- max `R_local_ulp = 0.7088`.

Existing head and ponding guards pass in the qualified set.

Frozen classification:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`.

## Interpretation

The eight above-floor stagnation cases are not physically unresolved in the sense of continued moisture-state representability.

Their residuals are already smaller than the arithmetic resolution implied by the stored `theta - theta_m1` representation, both locally and after aggregation.

The existing scalar balance gate is therefore stricter than the representable residual floor for these terminal states.

This does not invalidate BALTOL02 and does not authorize an empirical tolerance increase.

It supports a different concept: a representation-aware convergence certificate whose bound is computed from the actual stored state precision.

## Consequence

A separately preregistered test-only replay may evaluate a representation-aware certificate requiring:

1. existing head and ponding guards;
2. every local residual within its node-specific storage representation scale;
3. total residual within the aggregate storage representation scale;
4. finite route-consistent state;
5. unchanged physical accepted-interval and cumulative mass gates.

Only a positive replay may authorize a later production-shaped convergence-policy proposal.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No BALTOL02 or other numerical tolerance changed.

`LEGACY_NUMERICS` remains production default.
