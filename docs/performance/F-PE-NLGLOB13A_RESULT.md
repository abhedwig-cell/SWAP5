# F-PE-NLGLOB13A result — halfstep failure attribution

Date: 2026-09-29

Status:

`NLGLOB13A_MIXED_HALFSTEP_FAILURE`

Canonical base:

`integration/f-ci-canonical@15cd2388028d0eae2bec8ab5ab96db6aacf10497`

Qualification authority:

- workflow run: `36555124716`;
- job: `109362393556`;
- conclusion: SUCCESS.

## Coverage

PASS.

All seven frozen O05/TG HEAD/RUNOFF near-saturation target trajectories were reproduced with complete attribution diagnostics and no process failures.

## Failure classes

Counts:

- `HALF1_ACCEPTED_DOMAIN`: 5;
- `HALF2_ACCEPTED_DOMAIN`: 2;
- endpoint nonconvergence: 0;
- route/ponding/nonfinite failure: 0;
- other: 0.

No class reaches the frozen 6/7 dominance gate.

Frozen classification:

`NLGLOB13A_MIXED_HALFSTEP_FAILURE`.

## Physical state before failure

All pre-halfstep accepted states remain finite.

Maximum absolute cumulative physical ledger before the failed nominal interval is about:

`8.86e-15 cm`.

Thus the subdivision failures are not preceded by a physical mass anomaly.

## Interpretation

The one-level subdivision failure is entirely temporal-admissibility related.

Five trajectories already produce an out-of-domain accepted TG state in the first halfstep. Two survive the first halfstep but fail the second halfstep for the same accepted-state domain reason.

None of the seven returns to endpoint-globalization failure at the halfstep scale.

This rules out the hypothesis that one level of subdivision merely exposes the old nonlinear endpoint blocker.

It also shows that a deeper temporal subdivision experiment, if opened, must be able to subdivide the failing half-interval itself rather than only the original nominal interval.

## Consequence

NLGLOB13A does not authorize unbounded or adaptive recursive subdivision.

A separately preregistered successor may test one additional bounded subdivision level on only the failed half-interval:

`h -> h/2 + h/2`, and if one half fails accepted-state admissibility, only that half may be replaced by two `h/4` substeps.

No further depth is allowed in that successor.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
