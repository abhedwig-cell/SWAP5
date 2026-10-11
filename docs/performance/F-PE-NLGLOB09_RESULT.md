# F-PE-NLGLOB09 result — S0 test-only endpoint replay and physical admissibility

Date: 2026-09-29

Status:

`CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`

Canonical base:

`integration/f-ci-canonical@64f477f16eef5f87f52cdcc0615b1d0ae7b48375`

Qualification authority:

- workflow run: `36549557128`;
- job: `109344103992`;
- conclusion: SUCCESS.

## Frozen question

Can the unchanged NLGLOB07 S0 state-stationarity rule be used test-only to return an endpoint candidate instead of entering the normal nonconvergence retry path, while preserving physical mass and state admissibility?

## Coverage and recovery

All 96 frozen bank cases executed.

Completed requested horizon:

`75 / 96 = 0.78125`.

The preregistered positive recovery gate was >=0.80.

Therefore the replay misses the frozen gate by one percentage point and is classified negative.

Recovered cases span:

- TG and KLAG;
- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14.

Replay accept diagnostics:

`1214`

and every completed case contains the explicit:

`S0_STATE_STATIONARITY`

acceptance diagnostic.

## Physical admissibility

The recovered trajectories are physically very clean:

- maximum accepted-interval physical ledger: about `4.76e-14 cm`;
- maximum cumulative ledger: about `6.06e-14 cm`;
- all accepted states finite;
- process failures: 0.

Thus S0 replay does not expose a mass or finite-state defect on recovered cases.

## Remaining failures

21 trajectories do not complete.

They split into two distinct terminal families:

- 14 `ENDPOINT_SOLVE_FAILURE`;
- 7 `PREDICTED_RETENTION_DOMAIN_FAILED`.

The 7 retention-domain failures occur only in TG and are concentrated in O05 HEAD/RUNOFF ladders.

The 14 remaining endpoint failures span both TG and KLAG and multiple materials/routes.

This means the replay removes most but not all endpoint-globalization failures, while also exposing a separate current-step predictor-domain limitation that is not itself a nonlinear endpoint failure.

## Frozen classification

`CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`.

The physical safety gates pass, but the preregistered >=80% recovery gate does not.

Do not lower that gate post hoc.

## Interpretation

NLGLOB09 materially reduces the blocker:

- 75/96 formerly failing trajectories now complete;
- mass closure remains near roundoff;
- no unsafe replay acceptance is observed.

But research qualification is not yet complete.

The residual population must be decomposed rather than addressed by tuning S0.

There are now two bounded questions:

1. why do 14 replayed trajectories later encounter another endpoint failure without satisfying S0 before exhaustion?
2. why does the TG current-step moisture predictor leave the retention domain in 7 O05 HEAD/RUNOFF trajectories?

These should be treated separately.

## Production boundary

Research-only replay.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event default change.

`LEGACY_NUMERICS` remains production default.
