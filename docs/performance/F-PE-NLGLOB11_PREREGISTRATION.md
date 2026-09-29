# F-PE-NLGLOB11 preregistration — TG coefficient-stage predictor admissibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- NLGLOB10 Arm B: `NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`.

## Frozen question

Can the TG current-step coefficient predictor remain physically and numerically admissible when the auxiliary forward moisture predictor slightly exceeds saturation, without modifying the accepted moisture state or weakening the physical mass contract?

NLGLOB10 established that all 7 predictor-domain failures:

- start from finite accepted states inside the retention domain;
- overshoot only the upper saturation bound `theta_s`;
- never cross the dry bound `theta_r`;
- have maximum normalized overshoot about `5.17e-4`.

## Candidate: TG_KPRED_SAT_EXT

The accepted TG formula remains unchanged.

For the auxiliary coefficient-stage predictor only:

1. compute
   `theta_tilde = theta_n + h * theta_dot_n`;
2. where `theta_tilde < theta_s`, use the existing exact inverse;
3. where `theta_tilde >= theta_s`, define the coefficient-stage constitutive extension:
   - `h_tilde = 0`;
   - provider moisture input used for the temporary predicted state is `theta_s`;
   - `K_tilde = Ksat` through the same constitutive provider evaluated at `h=0`;
4. no accepted-state moisture is clipped or projected;
5. final `theta_TG` and accepted `h_TG` remain governed by the unchanged TG update and constitutive projection.

This is an explicit saturated extension of the auxiliary coefficient predictor, not a change in physical storage.

No lower-bound extension is opened because NLGLOB10 observed no lower-bound failure.

## Frozen gates

The candidate qualifies only if all hold:

1. the 7 NLGLOB10 predictor-domain failures no longer terminate as predictor-domain failures;
2. no new nonfinite or route-invalid state appears;
3. accepted TG states remain within the physical retention domain;
4. max accepted-interval physical ledger <= `5e-8 cm`;
5. max cumulative ledger <= `5e-8 cm`;
6. the original TIMEINT16C smooth fixed-flux bank still has:
   - 4/4 complete ladders;
   - median refined top-theta order >= 1.6;
   - median refined top-head order >= 1.6;
   - >=3/4 individual refined head orders >=1.5;
   - physical/cumulative ledgers <= `5e-8 cm`;
   - median work ratio versus KLAG BE <=1.15;
7. no dry-bound predictor failure is introduced.

Positive:

`QUALIFIED_TG_SATURATED_COEFFICIENT_STAGE_EXTENSION`.

If robustness improves but smooth second order is lost:

`CLOSED_TG_SAT_EXTENSION_ORDER_REGRESSION`.

If accepted state or mass fails:

`CLOSED_TG_SAT_EXTENSION_PHYSICAL_ADMISSIBILITY_FAILED`.

If the 7 failures persist:

`CLOSED_TG_SAT_EXTENSION_INSUFFICIENT`.

## Stop rules

No timestep reduction, clipping of accepted theta, history-K fallback, tolerance relaxation or empirical overshoot threshold.

## Production boundary

Research/test-only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
