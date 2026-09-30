# F-PE-ELASTIC60 — state-stratified independent budget bridge preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_ALPHA_DOMAIN_TRANSFER_AS_DOMINANT_BRIDGE_LIMITATION`

Parent postimage:
`research/f-pe-elastic59-real-history-budget-bridge@c44d1f001fd0658fc10263fbf28e9422cf939caa`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Purpose

Test whether a state-stratified scaling `alpha(Se)` can simultaneously satisfy:

1. realized-error conservatism:
   `H_INF <= alpha(Se) * Binf`;

2. independent PUB-P2E09 budget compatibility:
   `alpha(Se) * Binf <= T_h(Se)`.

No production tolerance or F-CI14 profile is created.

## Independent budget authority

Use exact frozen P2E09 U_h_inf envelopes:

- Se=0.65: `T=0.002329984405367469 cm`;
- Se=0.85: `T=0.024875926496918055 cm`;
- Se=0.98: `T=1.0304935719866082 cm`.

No interpolation between Se levels.

## Physical/numerical domain

Reuse exact ELASTIC59 / P2E08 selected-domain cases:
- materials: B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- forcing = DRYING, NOMINAL, WETTING;
- coarse dt = 0.0064 day;
- two half steps = 0.0032 + 0.0032;
- prescribed-flux bottom mode 2;
- admitted Reference solver;
- real stationary accepted history from ELASTIC59.

## Train / holdout split

Freeze before execution:

Training materials:
- B01;
- B12;
- O01.

Holdout materials:
- O05;
- O14;
- O18.

All three forcing classes and all three Se levels are retained in both sets.

The P2E09 budget itself is an external pre-existing authority and is not refit
from this split. Only the Binf scaling is trained.

## Training feasible interval

For each exact Se stratum and every paired training case with Binf > 0 define:

realized-error lower requirement:

`L(Se) = max_training(H_INF / Binf)`.

independent-budget upper requirement:

`U(Se) = min_training(T_h(Se) / Binf)`.

A feasible multiplicative bridge exists in training only if:

`L(Se) <= U(Se)`.

No compensation across Se strata is allowed.

## Frozen alpha choice

If the training interval is non-empty, choose the log-midpoint:

`alpha_train(Se) = sqrt(L(Se) * U(Se))`.

Rationale:
- scaling is multiplicative;
- log-midpoint gives symmetric multiplicative slack to lower and upper
  constraints;
- it is frozen before holdout inspection.

If `L=0`, use `alpha_train=0` only if all training H_INF in that Se stratum
are exactly zero; otherwise fail closed.

## Blind holdout gates

For every holdout case:

A. realized-error gate:
`H_INF <= alpha_train(Se) * Binf`;

B. budget gate:
`alpha_train(Se) * Binf <= T_h(Se)`.

Both must pass.

No alpha update is permitted after holdout inspection.

## Secondary observations

Report per Se:
- L;
- U;
- alpha_train;
- training multiplicative interval width U/L;
- holdout max H_INF/(alpha*Binf);
- holdout max alpha*Binf/T;
- holdout minimum lower/upper slack.

## Qualification gates

A1. Reproduce 54 valid exact P2E08/P2E09 cases.

A2. Real stationary history remains exact as in ELASTIC59.

A3. Defect indicator AVAILABLE in all 54 cases.

A4. Each training Se stratum has a non-empty feasible interval.

A5. Alpha is computed from training materials only.

A6. Holdout materials are never used in alpha construction.

A7. O0/O2 semantic identity.

A8. Zero `src/**` and `reference/**` changes.

## Decision

If all holdout lower and upper gates pass:

`QUALIFIED_STATE_STRATIFIED_INDEPENDENT_BUDGET_BRIDGE_RESEARCH_CANDIDATE`.

If any holdout lower gate fails:
`FALSIFIED_STATE_STRATIFIED_ERROR_CONSERVATISM`.

If any holdout upper gate fails:
`FALSIFIED_STATE_STRATIFIED_BUDGET_COMPATIBILITY`.

No result from ELASTIC60 authorizes production temporal limits, mode-7 transfer,
controller integration or F-CI14 admission.
