# F-PE-LIVE01 closeout — required live-trial cost rebaseline

Date: 2026-09-27

Status: `CLOSED_BASE_Q_STATE_RICHARDS_SOLVE_SELECTED`

PR:
`#656 — F-PE-LIVE01: required live-trial cost rebaseline`

Parent authority:
`F-PE-TEMPORAL08 / PR #655`

Current-head qualification run:
`36303861366`

## Purpose

LIVE01 rebaselined the exact SWAP work that the difficult live MODFLOW6 coupling
actually requires after production admission of the frozen c=0.65 temporal-history
policy.

The trigger was SOLVE01: discarded-trial solve elimination can be very fast in
reuse-rich synthetic/repeated workloads, but the frozen live matrix does not request
enough repeated correctors for that mechanism to improve aggregate live runtime.

LIVE01 therefore returned to the unavoidable exact trials.

## P0 — exact live demand

PASS.

Across the frozen 12-group difficult live matrix:

- exact SWAP trials: `32`;
- aggregate median coupled-loop time: `9,147,393 ns`;
- transaction calls: `52`;
- accepted substeps: `52`;
- attempts: `72`;
- retries: `20`;
- temporal rejections: `20`;
- solver rejections: `0`;
- internal retries: `0`;
- nonlinear iterations: `236`;
- Jacobian builds: `236`;
- linear solves: `380`;
- backtracking attempts: `236`.

The live route therefore contains real nonlinear work, but no solver-instability
rejection noise.

## P1 — accepted-direction / tangent cost

PASS.

Current-head aggregate replay:

- FULL: `925785 ns`;
- QONLY: `746820 ns`;
- `R_dir = 1.239636057`;
- directional marginal fraction: `19.3312%`;
- median group fraction: `17.8393%`;
- q identity: exact;
- nonlinear/retry trajectory: unchanged.

The preregistered primary-successor gate was `>=20%`.

Decision:

`DO_NOT_ADVANCE_DIRECTIONAL_AS_PRIMARY_SUCCESSOR`

The directional path is material, especially in some wet groups, but it remains
secondary to the base q/state solve under the frozen rule.

## P2 — temporal-retry cost bound

PASS.

A research-only wider floor was replayed on the same live head population with
directional work disabled in both arms.

Aggregate:

- PROD: `893686 ns`;
- WIDE: `897793 ns`;
- `R_retry = 0.995425449`;
- bounded retry fraction: about `-0.46%`;
- max relative q difference: `0`;
- retries: `20 -> 20`;
- attempts: `72 -> 72`.

The wider floor removes no retry because the history-dependent term, not the floor,
controls the relevant effective budget.

Decision:

`DO_NOT_ADVANCE_TEMPORAL_RETRY_AS_PRIMARY_SUCCESSOR`

No coefficient or production floor change is justified.

## Cross-check with post-TEMPORAL08 profiling

The parallel post-TEMPORAL08 PROFILE07 measurement independently keeps the
Reference backend as the dominant application-side cost, around 90% of repeated
application runtime in its current decomposition.

Its directional micro-cost remains large relative to plain Reference, but LIVE01
provides the more relevant live-trial discriminator and places that marginal
directional cost just below the frozen advancement threshold.

The two evidence lines therefore agree on the immediate target.

## Decision

The next primary performance workunit must decompose and reduce the
**base q/state Reference Richards solve** used by unavoidable live corrector trials.

This successor should remain exact-preserving initially.

It must distinguish at least:

- constitutive evaluation;
- residual assembly;
- Jacobian assembly/update;
- tridiagonal factorization/solve;
- backtracking candidate work;
- transaction/substep control overhead.

The target is not simply the largest microbenchmark kernel. Advancement requires
a measured contribution on the frozen live difficult population and a concrete
exact-preserving mechanism.

## Deferred, not rejected

Accepted-direction work remains a credible secondary target because its aggregate
marginal fraction is about 19.3% and several individual groups exceed 20%.

It is deferred only because the preregistered primary-successor gate was not met.

## No production change

LIVE01 changes no production source.

It does not change:

- c=0.65;
- the 1e-5 cm floor;
- BALTOL02;
- Richards equations;
- retry scale;
- tangent mathematics;
- MODFLOW equations;
- mass/publication ownership;
- process admission envelope.

## Closure

F-PE-LIVE01 is closed.

Immediate successor:

`F-PE-BASE01 — base q/state Richards solve decomposition`.

