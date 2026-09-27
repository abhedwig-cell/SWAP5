# F-PE-SETUP01 closeout — large-N setup decomposition

Date: 2026-09-27

Status: `CLOSED_LINEAR_UNIQUENESS_SUCCESSOR_SELECTED`

PR:
`#676 — F-PE-SETUP01: large-N production application-context setup decomposition`

## Decision

Large-N production bootstrap initialization is the dominant setup target.

At N=40,000:
- `app%initialize`: about 4.676 s;
- first warm trial: about 1.560 s;
- context materialization: about 0.052 s;
- topology/predictor preparation: about 0.0068 s.

The bootstrap path owns about 73% of measured setup through warm-up.

Code inspection identifies two O(N^2) uniqueness scans over tile and ledger identifiers as the strongest immediate candidate.

Select:

`F-PE-SETUP02 — linear uniqueness-validation qualification`

SETUP02 is research-only until duplicate-rejection semantics and performance are independently qualified.

## Production boundary

No production `src/**` change.
No physics, tolerance, temporal, tangent, transaction, aggregation or MODFLOW semantic change.

## Closure

`CLOSED_LINEAR_UNIQUENESS_SUCCESSOR_SELECTED`
