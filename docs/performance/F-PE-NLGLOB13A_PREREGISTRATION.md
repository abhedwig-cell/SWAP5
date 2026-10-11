# F-PE-NLGLOB13A preregistration — halfstep failure attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@15cd2388028d0eae2bec8ab5ab96db6aacf10497`

Parent authority:

- NLGLOB13: `CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`;
- seven frozen O05/TG HEAD/RUNOFF near-saturation trajectories fail one-level `h -> h/2 + h/2` subdivision;
- smooth second-order behavior and physical mass remain qualified.

## Purpose

NLGLOB13A is observational only.

It identifies exactly where the single-level subdivision fails and which failure class prevents the nominal interval from being committed.

No additional subdivision, tolerance change, accepted-state clipping, MAXIT change or K-staging change is introduced.

## Frozen target bank

Use exactly the seven NLGLOB13 near-saturation target trajectories:

- O05 / TG / HEAD at dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- O05 / TG / RUNOFF at dt = 0.00025, 0.000125, 0.00003125 d.

The O05 / TG / RUNOFF dt = 0.0000625 d trajectory is not part of this seven-case target because its parent failure is endpoint nonconvergence rather than the NLGLOB11A near-saturation accepted-state failure family.

## Frozen diagnostics

For every failed subdivision attempt record:

- nominal step index;
- failed half: 1 or 2;
- half-step dt;
- whether the half-step returned accepted-state retention-domain failure;
- the underlying terminal reason if the half-step failed for another reason;
- accepted pre-halfstep minimum and maximum theta;
- finite-state flag;
- target route;
- cumulative physical ledger before the failed nominal interval.

Failure classes are assigned without changing the solve:

1. `HALF1_ACCEPTED_DOMAIN`;
2. `HALF2_ACCEPTED_DOMAIN`;
3. `HALF1_ENDPOINT`;
4. `HALF2_ENDPOINT`;
5. `HALF1_ROUTE_OR_POND`;
6. `HALF2_ROUTE_OR_POND`;
7. `OTHER`.

Endpoint class means `ENDPOINT_SOLVE_FAILURE`.

Route/pond class includes route mismatch, negative ponding, top-provider failure, or nonfinite route/state failure.

## Frozen interpretation

Coverage requires all 7 target trajectories and exactly one terminal failed subdivision attribution per trajectory.

If >=6/7 trajectories share one class, classify that dominant class explicitly:

- `NLGLOB13A_FIRST_HALF_DOMAIN_DOMINANT`;
- `NLGLOB13A_SECOND_HALF_DOMAIN_DOMINANT`;
- `NLGLOB13A_FIRST_HALF_ENDPOINT_DOMINANT`;
- `NLGLOB13A_SECOND_HALF_ENDPOINT_DOMINANT`;
- `NLGLOB13A_ROUTE_POND_DOMINANT`.

Otherwise:

`NLGLOB13A_MIXED_HALFSTEP_FAILURE`.

If target coverage or diagnostics are incomplete:

`BLOCKED_NLGLOB13A_HALFSTEP_ATTRIBUTION`.

## Consequence

NLGLOB13A may authorize a separately preregistered successor targeted to the observed failure mechanism.

It does not authorize recursive subdivision by itself.

If the second half dominates accepted-state domain failure, a deeper subdivision experiment may be considered only for that second-half temporal interval and only after preregistration.

If endpoint nonconvergence dominates, the case returns to endpoint robustness rather than deeper temporal splitting.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
