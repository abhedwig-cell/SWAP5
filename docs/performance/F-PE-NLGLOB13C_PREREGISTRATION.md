# F-PE-NLGLOB13C preregistration — near-saturation accepted-state overshoot scaling

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ef08f11b5576bec92d66c445e0c577e680215487`

Parent authority:

- NLGLOB13A: all 7 frozen O05/TG near-saturation failures are accepted-state retention-domain failures at h/2;
- NLGLOB13B: all 7 remain accepted-state retention-domain failures at h/4;
- smooth second-order authority and physical mass remain preserved.

## Purpose

NLGLOB13C asks whether the accepted-state retention overshoot contracts systematically when the same failing half-interval is retried at half its temporal scale.

This is observational only.

No h/8 solve is executed and no state acceptance rule changes.

## Frozen target bank

Reuse exactly the seven NLGLOB13A/NLGLOB13B near-saturation target trajectories.

For each target trajectory, at the first failing nested subdivision sequence, record accepted-state domain failures at:

- the failing h/2 parent interval;
- the failing h/4 child interval retried from the same pre-half accepted state.

The nominal h failure may also be recorded but is not required for the primary parent-child scaling gate because, for half-2 failures, its pre-state differs from the failing child pre-state.

## Overshoot measure

For every accepted-state domain failure define:

`O = max((theta_r - min(theta_TG))/(theta_s-theta_r), (max(theta_TG)-theta_s)/(theta_s-theta_r), 0)`.

Also record:

- failing temporal scale;
- minimum and maximum prospective `theta_TG`;
- node carrying the maximum upper or lower overshoot;
- pre-subinterval minimum and maximum accepted theta;
- route and material;
- whether the failure is upper- or lower-bound.

For each target pair define:

`Q = O_(h/4) / O_(h/2)`

and apparent contraction exponent:

`p = log2(O_(h/2)/O_(h/4))`.

## Frozen interpretation

Classify:

`NLGLOB13C_OVERSHOOT_CONTRACTS_WITH_DT`

only if all hold:

1. 7/7 target trajectories produce finite paired h/2 and h/4 domain-failure diagnostics;
2. both paired failures originate from the same restored pre-half accepted state within roundoff-level stored-state identity;
3. all parent and child overshoots are strictly positive;
4. at least 6/7 targets satisfy `Q < 1`;
5. median `Q <= 0.60`;
6. median apparent exponent `p >= 0.5`;
7. no route, ponding, nonfinite or mass anomaly occurs before the paired failure.

If at most 3/7 targets satisfy `Q < 1` or median `Q >= 0.9`:

`NLGLOB13C_OVERSHOOT_NONCONTRACTING`.

Otherwise:

`NLGLOB13C_MIXED_OVERSHOOT_SCALING`.

If paired diagnostics cannot be established faithfully:

`BLOCKED_NLGLOB13C_SCALING_COVERAGE`.

## Consequence

A positive contraction result authorizes a separately preregistered bounded h/8 falsification workunit.

It does not itself authorize h/8 acceptance or recursive/adaptive subdivision.

A noncontracting or mixed result closes subdivision-depth escalation as the immediate default and redirects the line to a different near-saturation temporal formulation.

## Stop rules

Do not:

- execute h/8 in NLGLOB13C;
- tune the contraction gates after result exposure;
- clip accepted theta;
- alter S0/R0;
- change BALTOL02, MAXIT, backtracking or route physics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
