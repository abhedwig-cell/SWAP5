# F-PE-TIMEINT04 preregistration — closed-loop mixed-LTE adaptive backward Euler

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent:

F-PE-TIMEINT03.

## Purpose

Test whether the qualified mixed-state LTE mechanism can control backward-Euler timesteps directly, replacing iteration-count-based timestep selection in a research harness.

This workunit is calibration only.

No production source modification and no AUTO_REFERENCE admission in TIMEINT04.

## Error score

For every converged candidate step with accepted predecessor derivative history:

`e_h = 0.5 dt (h_dot_current-h_dot_previous)`

`e_theta = 0.5 dt (theta_dot_current-theta_dot_previous)`.

Frozen dimensionless score:

`S = max(max|e_h| / 0.50 cm, max|e_theta| / 1e-4)`.

These scales were preregistered in TIMEINT03 before its results and produced zero false-safe mechanism points.

## Startup

The first accepted interval has no predecessor derivative history.

Use one backward-Euler bootstrap step:

`dt_boot = sqrt(0.001 d * 0.020 d)`.

The bootstrap must converge and pass the unchanged mass-ledger gate.

After bootstrap, derivative history is available.

## Candidate acceptance

For every later candidate step:

- solve one backward-Euler interval transactionally from the accepted origin;
- calculate S;
- accept only if `S <= 1`;
- if `S > 1`, rollback candidate and retry from the same origin with reduced dt.

Solver nonconvergence is a separate retry reason.

Rejected candidates never update accepted derivative history.

## Step-size rule

Backward Euler local truncation error is O(dt^2), so use exponent 1/2.

After accepted step:

`factor = safety * S^(-1/2)`

with clamp:

`factor in [0.5, 2.0]`.

Frozen safety factors screened independently:

- A70: safety = 0.70;
- A80: safety = 0.80;
- A90: safety = 0.90.

For very small finite score:

`S_eff = max(S,1e-12)`.

Then:

`dt_next = dt * clamp(safety/sqrt(S_eff),0.5,2.0)`.

Research safety ceiling:

`dt <= 0.08 d`.

This 0.08 d ceiling is not a proposed user DTMAX. It is a test-harness guard equal to four times the historical 0.02 d ceiling.

Retry after temporal rejection:

`dt_retry = max(1e-6 d, dt * max(0.25, min(0.8, safety/sqrt(S))))`.

Retry after nonlinear failure:

`dt_retry = max(1e-6 d, 0.5*dt)`.

## Event boundary

The 0.12 d test horizon is an exact hard stop.

No step may cross it.

There are no other event boundaries in this calibration bank.

## Comparator

Current corrected LEGACY_NUMERICS adaptive Reference on identical cases and forcing.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

This is coefficient selection only.

## Quality gate

Use P-C1 unchanged versus current Reference:

- cumulative runoff:
  - <=0.01 cm absolute when Reference runoff <1 cm;
  - otherwise <=1%;
- terminal storage <=max(0.01 cm,0.5% Reference terminal storage);
- terminal ponding <=0.02 cm;
- terminal top/mid/bottom head <=2.0 cm;
- max ledger <=5e-8 cm;
- no terminal solver failure;
- rejected attempts <=50% of total attempts.

The retry fraction is allowed to exceed legacy because the new controller explicitly uses temporal rejection, but pathological retry behavior is not accepted.

## Performance metric

Primary:

total deterministic work including all rejected temporal/solver candidates:

`nonlinear iterations + backtracks + Jacobian builds + linear solves`.

A candidate advances only if:

1. >=15/16 P-C1 pass;
2. every WET/POND case passes;
3. median total deterministic work reduction >=15%;
4. no case exceeds 50% rejected attempts;
5. no mass regression.

Selection among advancing safety factors:

1. highest P-C1 pass count;
2. highest median work reduction;
3. fewer temporal rejections;
4. larger safety factor only if still tied.

## Advancement

If one factor advances:

- freeze it;
- freeze all score scales, exponents, clamps, ceilings and retry rules;
- construct a new blind validation bank before exposure.

If none advances:

- do not tune the score scales post hoc;
- proceed to BDF2 mechanism research.

## Production boundary

Research-only.

Possible TIMEINT04 outcomes:

- `MIXED_LTE_ADAPTIVE_BE_CALIBRATION_CANDIDATE`;
- `CLOSED_MIXED_LTE_CONTROLLER_NO_GAIN`.
