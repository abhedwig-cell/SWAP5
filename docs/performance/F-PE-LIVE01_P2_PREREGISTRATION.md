# F-PE-LIVE01 P2 preregistration — temporal-retry cost bound

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-LIVE01 P1`

## Trigger

P1 measured accepted-direction / tangent production at 19.7705% of aggregate exact-trial wall-clock, narrowly below the frozen 20% primary-successor gate.

Approximately 80.2% of exact-trial wall-clock remains in the base q/state solve.

P0 showed that the current production-shaped c=0.65 live matrix executes:

- 72 attempts;
- 52 accepted substeps;
- 20 retries;
- all 20 retries are temporal rejections;
- zero solver rejections;
- zero internal retries.

The next question is whether those temporal retries are a large fraction of the remaining base-solve cost.

## Primary question

How much q/state trial wall-clock is associated with the current temporal-retry path on the exact live head population?

## Frozen method

Use the same live head sequences captured from the 12-group P0/P1 matrix.

For each group, recreate identical dynamic origins and replay the same heads with accepted-direction production disabled in both arms.

### PROD

Current production temporal policy:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`.

### WIDE

Research-only wide temporal envelope:

- same coefficient `0.65`;
- frozen floor `0.02 cm`.

This arm exists only to suppress or strongly reduce temporal retry work in replay.

It is not a production candidate and is not an admission proposal.

The qualified BALTOL02 balance-floor authority remains identical in both arms.

## Why accepted-direction is disabled

P1 has already measured directional work separately.

Disabling it identically in PROD and WIDE prevents directional linear solves from obscuring the temporal-retry cost comparison.

## Measurements

Per group and arm:

- total trial wall-clock;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- temporal rejections;
- solver rejections;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- headcalc calls;
- backtracking attempts;
- q at every replayed head.

Report:

`R_retry = T_PROD / T_WIDE`

and:

`F_retry_bound = (T_PROD - T_WIDE) / T_PROD`.

Also report q differences introduced by the wide temporal envelope.

## Interpretation boundary

WIDE may change the accepted numerical trajectory because it changes temporal acceptance.

Therefore `F_retry_bound` is a counterfactual runtime bound, not automatically an exact component attribution.

The result becomes a stronger attribution only where:

- WIDE removes temporal retries;
- q differences remain negligible on the frozen head population;
- solver/nonlinear behavior otherwise remains interpretable.

All q differences must be reported, not hidden behind a pass/fail gate.

## Advancement rule

A dedicated temporal-retry optimization successor is justified only if both are true:

1. aggregate `F_retry_bound >= 0.20`;
2. the maximum relative q difference on the frozen live head population is <=0.1%.

If the runtime fraction is below 20%, continue decomposing the retained base nonlinear solve.

If runtime gain is large but q differences exceed 0.1%, treat the result as evidence that retry removal changes the numerical solution materially and do not promote it as a simple performance optimization.

## Non-goals

P2 does not:

- change production c=0.65 policy;
- admit the WIDE policy;
- change mass-balance authority;
- change MODFLOW iteration logic;
- optimize the tangent;
- modify `src/**`.

No production source change is authorized.
