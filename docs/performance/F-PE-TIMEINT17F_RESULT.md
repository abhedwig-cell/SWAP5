# F-PE-TIMEINT17F result — route-specific nonlinear failure localization

Date: 2026-09-29

Status:

`TIMEINT17F_ROUTE_STRUCTURED_INTERIOR_DOMINANCE`

Secondary attribution:

`TIMEINT17F_TG_KLAG_LOCALIZATION_DIVERGENCE`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36533544096`;
- job: `109293288574`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17F localized the route-specific nonlinear failures identified by TIMEINT17E without changing solver behavior.

The same TIMEINT17A2 fixtures, numerical settings, dynamic-top provider and conductivity staging were retained.

## FLUX

TG endpoint failures:

`16`

Dominant residual location:

- TOP: 2;
- INTERIOR: 12;
- BOTTOM: 2.

Classification:

`TIMEINT17F_FLUX_INTERIOR_RESIDUAL_DOMINANT`.

Matched KLAG FLUX failures:

- TOP: 1;
- INTERIOR: 13;
- BOTTOM: 2.

Thus the FLUX line-search/stagnation blocker is not a top-boundary residual defect. The dominant residual is usually interior.

## HEAD

TG endpoint failures:

`16`

Dominant residual location:

- TOP: 1;
- INTERIOR: 13;
- BOTTOM: 2.

Classification:

`TIMEINT17F_HEAD_INTERIOR_COMPARTMENT_GATE`.

Matched KLAG HEAD:

- TOP: 1;
- INTERIOR: 15;
- BOTTOM: 0.

The post-step convergence blocker is therefore predominantly an interior compartment-balance issue rather than a surface/ponding gate.

## RUNOFF

TG endpoint failures:

`16`

Dominant residual location:

- TOP: 1;
- INTERIOR: 10;
- BOTTOM: 5.

Classification:

`TIMEINT17F_RUNOFF_INTERIOR_COMPARTMENT_GATE`.

Matched KLAG RUNOFF:

- TOP: 0;
- INTERIOR: 14;
- BOTTOM: 2.

RUNOFF is more spatially mixed in TG than HEAD, but the top node remains rare as dominant residual location.

## TG versus KLAG exact localization

Matched endpoint-failure pairs:

`48`

Pairs with identical dominant localization and gate-count signature:

`8 / 48`

Shared exact-localization fraction:

`0.1666666667`

Secondary classification:

`TIMEINT17F_TG_KLAG_LOCALIZATION_DIVERGENCE`.

This does not contradict the shared endpoint blocker from TIMEINT17B/C. The broad failing subsystem is shared, but the detailed nonlinear trajectory within that subsystem diverges between TG and KLAG.

## Main conclusion

The TIMEINT17 nonlinear blocker is not localized to the dynamic-top top row.

Across all three route families the failing residual is predominantly interior.

That changes the next attribution target.

TIMEINT17D certified only:

- provider surface-head derivative;
- full top-row residual/Jacobian.

It did not certify the complete 16-node residual/Jacobian operator.

Given F, the next bounded question is whether the interior/full-column Jacobian is consistent with the actual residual under the same fixed-K candidate state.

## Required successor

Open:

`F-PE-TIMEINT17G — full-column residual/Jacobian finite-difference attribution`.

TIMEINT17G should:

- use the identical A2 states and fixed-K authority;
- finite-difference all 16 residual rows with respect to all pressure-head unknowns needed by the tridiagonal stencil;
- compare lower/main/upper analytic coefficients with the residual operator;
- report row/node localization of any mismatch;
- avoid all solver tuning.

If the complete Jacobian passes, TIMEINT17 should stop attributing algebra and move to nonlinear globalization/state-scaling research.

If interior Jacobian mismatch is found, any repair must be separately preregistered and requalified before production code changes.

## Production boundary

No production `src/**` change.

No convergence-tolerance change.

No MAXIT/backtracking change.

No event-localization change.

`LEGACY_NUMERICS` remains production default.
