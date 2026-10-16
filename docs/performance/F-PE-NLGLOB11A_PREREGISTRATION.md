# F-PE-NLGLOB11A preregistration — head-space endpoint coefficient predictor

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2a91ef7a4ed3a211528538ba2f809993f820f300`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- NLGLOB10 Arm B: `NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`;
- NLGLOB11: fixed half-step moisture predictor falsified and smooth order regressed to about one.

## Purpose

Preserve the endpoint temporal location required by the qualified TIMEINT16C mechanism while avoiding direct forward extrapolation of moisture beyond the constitutive retention domain.

NLGLOB11A tests a head-space endpoint predictor derived from the accepted-state chain rule.

## Frozen candidate — TG_HEADSPACE_ENDPOINT_STAGE

At accepted state `(theta_n,h_n)`:

1. evaluate the accepted-origin physical moisture derivative `theta_dot_n`;
2. evaluate the same constitutive provider at `h_n` and obtain capacity `C_n=dtheta/dh`;
3. require every active `C_n` used by the predictor to be finite and strictly positive;
4. form
   `h_dot_n = theta_dot_n / C_n`;
5. require `h_dot_n` and
   `h_tilde = h_n + h*h_dot_n`
   to be finite;
6. evaluate the same constitutive provider directly on `h_tilde` and obtain `K_tilde`;
7. hold `K_tilde` fixed during the BE-like endpoint solve exactly as in TIMEINT16C;
8. retain the unchanged TG accepted update:
   `theta_TG = theta_n + 0.5*h*(theta_dot_n+theta_dot_p)`;
9. require the accepted `theta_TG,h_TG` pair to pass the existing exact retention roundtrip and physical-domain checks.

Positive predicted pressure head is allowed and is interpreted through the same constitutive provider. No moisture clipping, head clipping, fitted capacity floor or empirical threshold is introduced.

## Fail-closed conditioning rule

The candidate is unavailable for an interval if any active predictor capacity is:

- nonfinite;
- <= 0;

or if any derived `h_dot_n`, `h_tilde` or `K_tilde` is nonfinite or the provider does not return a valid positive conductivity.

No small-capacity numerical floor is introduced in NLGLOB11A. If finite positive capacity still produces an unusable predictor, that is an observed candidate failure rather than a post-hoc threshold-tuning opportunity.

## Mandatory Bank S — smooth TIMEINT16C regression

Reuse the original four fixed-flux ladders.

Frozen gates:

1. 4/4 ladders complete;
2. median refined top-head order >= 1.6;
3. median refined top-theta order >= 1.6;
4. >=3/4 individual refined head orders >=1.5;
5. physical per-step ledger <= `5e-8 cm`;
6. cumulative ledger <= `5e-8 cm`;
7. theta roundtrip <= `1e-12`;
8. endpoint native balance residual <= `5e-8 cm/d`;
9. zero invalid head-space predictors;
10. median work per step <=1.15x KLAG BE.

## Mandatory Bank D — dynamic-top replay

Reuse the exact NLGLOB09 96-case bank and unchanged S0 replay.

Frozen gates:

1. 96/96 execute without process failure;
2. zero `PREDICTED_RETENTION_DOMAIN_FAILED`;
3. zero accepted TG retention-roundtrip/domain failure;
4. complete requested horizon in >=80% of cases;
5. completed cases span TG and KLAG, all 3 routes and >=3 materials;
6. max accepted-interval physical ledger <= `5e-8 cm`;
7. max cumulative ledger <= `5e-8 cm`;
8. all completed states finite and route-consistent;
9. no new dry-side constitutive failure;
10. S0 replay semantics remain unchanged.

The separate 14 above-floor endpoint failures are not required to disappear unless the changed TG staging happens to alter them.

## Frozen classifications

If both banks pass:

`QUALIFIED_TG_HEADSPACE_ENDPOINT_STAGE_RESEARCH`.

If Bank S loses order:

`CLOSED_TG_HEADSPACE_STAGE_ORDER_REGRESSION`.

If dynamic head-space prediction is invalid or fails to remove the target domain problem:

`CLOSED_TG_HEADSPACE_STAGE_ROBUSTNESS_FAILED`.

If accepted TG state or mass is invalid:

`CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED`.

## Stop rules

Do not introduce after result exposure:

- a capacity floor;
- predictor damping factor;
- head clipping;
- accepted-theta clipping;
- historical K;
- tolerance relaxation;
- MAXIT/backtracking increase;
- timestep change.

A different regularized chain-rule predictor requires separate preregistration.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected effect: research-only auxiliary coefficient staging; accepted physical state and mass contract unchanged.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB11A

BASELINE: `2a91ef7a4ed3a211528538ba2f809993f820f300`

BRANCH: `research/f-pe-nlglob11a-headspace-predictor`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize head-space endpoint predictor in smooth and dynamic research harnesses

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
