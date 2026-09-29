# F-PE-NLGLOB07 preregistration — representational accepted-state stationarity attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB04: `NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`;
- NLGLOB05: `NLGLOB05_CERTIFICATE_NONSPECIFIC`;
- NLGLOB06: `NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`.

## Purpose

NLGLOB07 asks a different question from NLGLOB05/06.

The rejected certificates relied on residual, correction, merit and rho persistence. NLGLOB07 instead tests whether terminal endpoint exhaustion can be identified from the **accepted candidate state itself becoming representationally stationary** across consecutive Newton origins.

The primary state is conserved moisture.

Pressure-head convergence remains an independent guard, not a substitute for moisture-state evidence.

P0 is observational only.

## Frozen bank

Reuse the unchanged TIMEINT17 A2 / NLGLOB01-06 bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- MAXIT = 8;
- MaxBackTr = 8;
- unchanged dynamic-top provider;
- unchanged K staging;
- unchanged BALTOL02, head and ponding contracts.

No case may be removed after outcome exposure.

## Physical-state displacement

For each post-backtracking Newton origin k and node i, let:

`theta_i^k`

be the exact logged candidate water content.

For transition k-1 -> k define:

`u_i^k = ulp(theta_i^k) + ulp(theta_i^(k-1))`

and

`d_i^k = |theta_i^k - theta_i^(k-1)| / max(u_i^k, tiny)`.

Primary max-node displacement:

`D_theta_inf^k = max_i d_i^k`.

Also define a volume-weighted absolute storage displacement:

`DeltaS_abs^k = sum_i dz_i f_i |theta_i^k-theta_i^(k-1)|`

with representational scale:

`U_S^k = sum_i dz_i f_i u_i^k`

and normalized storage displacement:

`D_S^k = DeltaS_abs^k / max(U_S^k,tiny)`.

These are observation ratios. They do not redefine physical mass or solver tolerances.

## Frozen local physical guard G0

An evaluation point k is physically/numerically eligible only if the current iteration satisfies:

1. `r_bal <= 10`;
2. dominant-node `r_storage_ulp <= 10`;
3. existing head-update contract `r_head <= 1`;
4. ponding contract is either not applicable or `r_pond <= 1`;
5. finite diagnostics;
6. provider route equals the frozen fixture route.

No rho condition is used in NLGLOB07.

## Frozen stationarity certificate S0

S0 is evaluated only when states k-2, k-1 and k are present.

S0 is true iff:

### S0.1 Current physical guard

Iteration k satisfies G0.

### S0.2 Two consecutive representationally stationary moisture transitions

For both transitions k-2 -> k-1 and k-1 -> k:

- `D_theta_inf <= 32`;
- `D_S <= 32`.

The fixed 32-ULP envelope is chosen before results as a conservative representational neighborhood large enough to cover several arithmetic operations while remaining orders of magnitude below any physically meaningful moisture change.

### S0.3 No renewed state motion

The second transition may not increase normalized state motion materially:

`D_S^k <= 2 * max(D_S^(k-1),1)`.

This prevents a single stationary transition followed by renewed evolution from certifying exhaustion.

### S0.4 Route/state continuity

All three states are finite and retain the intended route.

S0 does not publish or accept a state.

## Frozen positive population

For each of the 96 endpoint-failure trajectories, the final audited iteration is the terminal target.

A trajectory is terminal-certifiable if S0 is true at the final iteration.

## Frozen negative controls

### N1 — early trajectory

All eligible k strictly earlier than the final two Newton iterations.

S0 false-positive fraction must be <= 1%.

### N2 — adequate-model control

All eligible k with selected rho >= 0.25 at k.

This remains a diagnostic control only; rho is not part of S0.

S0 false-positive fraction must be <= 5%.

### N3 — above-floor control

Current `r_bal > 10`.

Reject 100%.

### N4 — storage-floor-absent control

Current `r_storage_ulp > 10`.

Reject 100%.

### N5 — head/ponding unresolved control

Current `r_head > 1` or applicable `r_pond > 1`.

Reject 100%.

### N6 — route/nonfinite control

Any route mismatch or nonfinite state in the three-state window.

Reject 100%.

## Frozen qualification gates

Classify:

`NLGLOB07_STATE_STATIONARITY_DISCRIMINATOR_QUALIFIED`

only if all hold:

1. complete 96-case bank;
2. >=90 terminal trajectories have a complete three-state window;
3. terminal certification fraction >= 0.50;
4. certified terminals include TG and KLAG, all 3 routes and at least 3 materials;
5. at least 4/6 route-mode families have terminal certification >= 0.40;
6. N1 early false-positive fraction <= 0.01;
7. N2 adequate-model false-positive fraction <= 0.05;
8. N3-N6 false-positive fraction = 0;
9. no classification depends on altered solver thresholds or storage-derived external flux.

If N3-N6 fail:

`NLGLOB07_STATE_STATIONARITY_UNSAFE`.

If N1 or N2 fails while hard controls pass:

`NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`.

If terminal certification < 0.20:

`NLGLOB07_STATE_STATIONARITY_NOT_USEFUL`.

If coverage fails:

`BLOCKED_NLGLOB07_STATE_STATIONARITY_COVERAGE`.

Otherwise:

`NLGLOB07_MIXED_STATE_STATIONARITY_SIGNAL`.

## Positive consequence

A positive P0 authorizes only a separately preregistered test-only endpoint replay.

Replay must retain:

- unchanged physical accepted-interval mass gate;
- unchanged route semantics;
- finite state;
- existing head and ponding guards;
- explicit diagnostic acceptance reason.

Production convergence is not changed by P0.

## Stop rule

Do not tune after result exposure:

- 32-ULP thresholds;
- two-transition requirement;
- factor-2 renewed-motion guard;
- positive or negative population definitions.

A negative result closes S0.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected P0 effect: diagnostic only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB07

BASELINE: `30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`

BRANCH: `research/f-pe-nlglob07-state-stationarity`

SCOPE: observational accepted-state stationarity discrimination

INTERFACES CHANGED: none

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement S0 observational harness on the frozen bank

RECOVERY POINT: this preregistration commit

DEPENDENCIES / BLOCKERS: endpoint replay blocked until S0 qualifies

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
