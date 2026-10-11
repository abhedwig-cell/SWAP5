# F-PE-NLGLOB09 closeout — S0 test-only endpoint replay

Date: 2026-09-29

Final status:

`CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@64f477f16eef5f87f52cdcc0615b1d0ae7b48375`

Qualification authority:

- run `36549557128`;
- job `109344103992`;
- conclusion: SUCCESS.

## Closure

NLGLOB09 closes the first S0 replay attempt as physically safe but insufficiently complete.

The replay recovers 75/96 trajectories, or 78.125%, below the frozen 80% qualification gate.

The recovered set is broad across both modes, all routes and all materials.

Physical mass is not the blocker:

- max per-interval ledger ≈ `4.76e-14 cm`;
- max cumulative ledger ≈ `6.06e-14 cm`;
- all recovered states finite;
- no process failures.

## Remaining blocker decomposition

The 21 residual failures separate cleanly:

- 14 later `ENDPOINT_SOLVE_FAILURE` trajectories;
- 7 `PREDICTED_RETENTION_DOMAIN_FAILED` trajectories.

The endpoint-failure subset remains a nonlinear robustness question after earlier S0 replay.

The retention-domain subset is TG-specific and must not be conflated with nonlinear globalization. It is a current-step moisture-predictor admissibility problem.

## Consequence

Do not rescue NLGLOB09 by lowering the 80% gate or changing S0.

Open separate bounded attribution:

`F-PE-NLGLOB10 — post-replay residual-failure decomposition`.

NLGLOB10 should first observe, without new solver behavior:

1. whether the 14 later endpoint failures again reach NLGLOB07/NLGLOB08 state-stationarity/tail-inertness structure;
2. at what step and state the 7 TG predictor-domain failures cross the retention domain;
3. whether the latter reflect physically impossible theta prediction or merely first-order predictor overshoot while the accepted state remains admissible.

Only after those two populations are separated may a replay/fallback rule be preregistered.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB09

BASELINE: `64f477f16eef5f87f52cdcc0615b1d0ae7b48375`

BRANCH: `research/f-pe-nlglob09-s0-replay`

STATUS: closed negative

IMPLEMENTATION STATUS: test-only S0 replay persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`

DEPENDENCIES / BLOCKERS: 14 later endpoint failures plus 7 TG predictor-domain failures

NEXT SAFE STEP: preregister NLGLOB10 residual-failure decomposition

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
