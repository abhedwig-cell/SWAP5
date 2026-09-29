# F-PE-NLGLOB12B preregistration — bounded extra-iteration falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Parent authority:

- NLGLOB12: `NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`;
- descending subset: exactly 6 trajectories classified `ABOVE_FLOOR_STILL_DESCENDING`;
- NLGLOB09 S0 replay semantics remain unchanged.

## Purpose

NLGLOB12B tests one bounded hypothesis only:

the six preregistered descending endpoint failures are limited by the current nonlinear iteration budget rather than by an irreducible above-floor stagnation mechanism.

The test changes only the research-harness nonlinear iteration budget for these six cases.

## Frozen subset

The six cases are fixed before result exposure:

1. B12 / TG / HEAD / dt = 0.000125 d;
2. O05 / TG / HEAD / dt = 0.00003125 d;
3. O14 / TG / HEAD / dt = 0.0000625 d;
4. O14 / KLAG / HEAD / dt = 0.0000625 d;
5. O14 / TG / HEAD / dt = 0.00003125 d;
6. O14 / KLAG / RUNOFF / dt = 0.00003125 d.

The exact case identities must be checked against the NLGLOB12 persisted record before execution. If any identity does not match that record, stop as coverage-blocked rather than silently changing the subset.

## Candidate

Research-only:

- increase `max_iterations` from 8 to 16;
- keep `max_backtracking = 8`;
- keep every residual, head, ponding and BALTOL02 tolerance unchanged;
- keep S0 replay unchanged;
- keep timestep, K staging, dynamic-top provider and route semantics unchanged;
- introduce no new damping, trust-region, clipping or acceptance rule.

The additional eight iterations are therefore a falsification of an iteration-budget hypothesis, not a proposed production default.

## Frozen diagnostics

For each of the six trajectories record:

- whether requested horizon completes;
- whether convergence is ordinary or S0 replay;
- iteration count at the formerly failing endpoint;
- final terminal reason if still failing;
- max accepted-interval physical ledger;
- cumulative physical ledger;
- route and finite-state validity;
- deterministic nonlinear/backtracking work relative to the original MAXIT=8 trajectory.

## Frozen qualification gates

Classify:

`NLGLOB12B_BOUNDED_EXTRA_ITERATIONS_SUPPORTED`

only if all hold:

1. exact 6/6 frozen cases execute;
2. at least 5/6 complete the requested horizon;
3. all completed trajectories preserve their intended route;
4. all completed accepted states are finite;
5. max accepted-interval physical ledger <= `5e-8 cm`;
6. max cumulative physical ledger <= `5e-8 cm`;
7. no tolerance or backtracking change;
8. no case requires more than the frozen 16-iteration limit.

If <=2/6 complete:

`NLGLOB12B_EXTRA_ITERATIONS_NOT_SUPPORTED`.

If 3/6 or 4/6 complete while safety gates pass:

`NLGLOB12B_MIXED_EXTRA_ITERATION_SIGNAL`.

If mass, route or finite-state safety fails:

`NLGLOB12B_EXTRA_ITERATIONS_PHYSICALLY_UNSAFE`.

If the exact subset cannot be reproduced:

`BLOCKED_NLGLOB12B_SUBSET_COVERAGE`.

## Interpretation rule

A positive result supports only a bounded fallback/budget mechanism for the identified descending class.

It does not authorize globally changing MAXIT from 8 to 16.

A production candidate would still need an observable classifier or retry policy that distinguishes this class before applying extra work.

## Stop rules

Do not alter after result exposure:

- the six-case subset;
- MAXIT=16;
- recovery threshold;
- tolerances;
- backtracking;
- timestep;
- S0;
- K staging.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected effect: research-only execution-budget falsification.

## Production boundary

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
