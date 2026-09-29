# F-PE-NLGLOB10 result — post-replay residual-failure decomposition

Date: 2026-09-29

Status:

Arm A: `NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR`

Arm B: `NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`

Canonical base:

`integration/f-ci-canonical@3fe1e5e6f908f819509f8c1b5ab7438b40267a37`

Qualification authority:

- workflow run: `36550225479`;
- job: `109346307296`;
- conclusion: SUCCESS.

## Coverage

PASS.

The exact 96-case NLGLOB09 replay bank was reproduced with no process failures.

Residual failures remain:

- 14 `ENDPOINT_SOLVE_FAILURE`;
- 7 `PREDICTED_RETENTION_DOMAIN_FAILED`.

## Arm A — remaining endpoint failures

All 14/14 endpoint failures are blocked by the unchanged balance/storage guard:

`A_GUARD_BALANCE = 14`.

No terminal case is primarily classified as:

- head/ponding guard;
- state-motion guard;
- renewed-motion guard;
- route/state guard.

Frozen Arm-A classification:

`NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR`.

Therefore the remaining endpoint population is not a hidden S0 false negative. At the point of exhaustion it has not yet reached the already qualified numerical floor neighborhood required by S0.

This population must not be accepted by weakening S0.

## Arm B — TG predictor-domain exits

All 7/7 predictor-domain failures start from finite accepted states strictly inside the retention domain.

Only the explicit current-step first-order moisture predictor crosses the constitutive retention bound.

Frozen Arm-B classification:

`NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`.

Maximum normalized overshoot relative to the full material water-content range:

`5.17049e-4`.

Thus the accepted physical state is not defective. The failure belongs to the auxiliary coefficient-stage predictor used to evaluate `K_tilde`.

## Scientific interpretation

NLGLOB10 separates the post-NLGLOB09 blocker into two independent mechanisms.

1. The residual 14 endpoint failures remain genuine nonlinear endpoint failures above the floor. They require a separate robustness treatment and cannot be rescued by S0.
2. The 7 TG-only failures are small forward-predictor domain overshoots from valid accepted states. They are not physical accepted-state failures and not endpoint-globalization failures.

The two mechanisms must remain separate.

## Consequence

Open separate successors.

### TG predictor successor

A separately preregistered predictor-admissibility workunit may test a mathematically defined in-domain coefficient-stage predictor.

It must not silently clip accepted moisture.

Any candidate must preserve:

- accepted-state moisture;
- physical interval mass;
- current-step-only coefficient staging;
- provider consistency;
- second-order accuracy authority from TIMEINT16.

### Endpoint successor

The 14 above-floor endpoint failures require separate nonlinear robustness attribution or method work.

Do not weaken the S0 floor guard.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging default or route/event change.

`LEGACY_NUMERICS` remains production default.
