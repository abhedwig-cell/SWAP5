# F-PE-BOFEK01 P1R preregistration — fixed-step oracle solvability characterization

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_P1R_RESULTS`

Canonical authority:

`integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

Parent evidence:

- P0 strict adaptive-policy screening: no advancing candidate.
- P1 independent fixed-step oracle attempt: Actions run `36413551568`.
- P1 oracle convergence: 1/16 screening cases.
- BALTOL02 effective balance floor was active and is not the blocker.

## Question

Are the P1 fixed-step oracle failures caused by insufficient nonlinear solver effort at fixed dt, rather than by an unsuitable temporal refinement target?

This is an oracle-solvability diagnostic. It does not change candidate policy gates and does not authorize a production MAXIT change.

## Frozen temporal points

Keep the P1 temporal levels unchanged:

- coarse oracle dt = 0.0005 d;
- fine oracle dt = 0.00025 d;
- horizon = 0.12 d.

No finer dt is introduced in P1R.

## Solver-effort arms

For each of the 16 screening cases, run both fixed dt levels with:

- O8: max_iterations=8, max_backtracking=8, existing P1 control;
- O20: max_iterations=20, max_backtracking=8;
- O48: max_iterations=48, max_backtracking=8.

All other controls remain unchanged:

- SWKIMPL=0;
- fixed-K dynamic-top BOFEK00 route;
- BALTOL02 effective balance floor;
- strict head tolerance;
- strict ponding tolerance;
- same hydraulic parameters and forcing.

Backtracking is held fixed so the first diagnostic isolates nonlinear iteration capacity.

## Metrics

Record for every run:

- completion;
- accepted/rejected attempts;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- terminal top/mid/bottom head;
- terminal storage;
- ponding;
- cumulative runoff;
- maximum ledger residual.

For runs that complete at both 0.0005 d and 0.00025 d, apply the already frozen P1 temporal-resolution gate.

## Decision rules

1. If O20 or O48 restores fixed-step completion broadly and coarse/fine convergence passes, the independent oracle may use the smallest solver-effort arm that restores all or nearly all screening cases. This is reference computation effort, not a production policy recommendation.
2. If O20 and O48 still fail most cases at the same fixed dt levels, classify the P1 oracle construction as unsuitable under current Reference solver authority. Do not chase smaller dt post hoc.
3. If only isolated cases fail, retain them as unresolved and do not use them to qualify candidate policy.
4. Candidate policy advancement remains exactly the P1 rule: all temporally resolved screening cases must pass oracle accuracy and median deterministic work reduction must be at least 8%.
5. No interaction, holdout, production write or practical-mode inference occurs in P1R.

## Stop condition

If no solver-effort arm yields a sufficiently broad independent fixed-step oracle, close the strict workunit as `CLOSED_NO_POLICY_GAIN_ORACLE_LIMITED` unless another already-preregistered independent Reference authority exists in the repository.

