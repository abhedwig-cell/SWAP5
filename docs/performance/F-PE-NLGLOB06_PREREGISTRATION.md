# F-PE-NLGLOB06 preregistration — Newton-trajectory exhaustion discrimination

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2332a59d2ec33245f53593960e0c334525eda148`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- NLGLOB02: `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`;
- NLGLOB03: `NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`;
- NLGLOB04: `NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`;
- NLGLOB05: `NLGLOB05_CERTIFICATE_NONSPECIFIC`.

## Purpose

NLGLOB06 tests the remaining bounded hypothesis from NLGLOB05:

the storage/balance-floor signature is physically real but not specific when evaluated at one Newton iteration; terminal numerical exhaustion may instead be identifiable from persistence and lack of progress across consecutive accepted Newton origins.

The first phase is observational only.

It does not alter:

- residual equations;
- analytic Jacobian;
- dynamic-top provider;
- K staging;
- BALTOL02;
- head or ponding tolerances;
- MAXIT or MaxBackTr;
- timestep;
- route semantics;
- transaction semantics;
- physical interval mass acceptance.

## Frozen bank

Reuse the exact TIMEINT17 A2 / NLGLOB01-05 endpoint-failure bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and matched KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged A2 route-margin fixtures;
- MAXIT = 8;
- MaxBackTr = 8;
- unchanged dynamic-top provider;
- unchanged K staging;
- unchanged BALTOL02.

The observational harness may deterministically rematerialize the unchanged bank because earlier iteration logs are CI evidence rather than versioned repository fixtures. Such reruns do not constitute a solver-behaviour change.

## Frozen per-iteration inputs

For every post-backtracking Newton iteration, carry forward already qualified diagnostics:

- `r_bal = max(r_cp,r_tot)`;
- dominant-node `r_storage_ulp`;
- normalized head update `r_head`;
- ponding ratio when applicable;
- `z_h_inf`;
- selected composite merit `M`;
- best tested composite merit among the already tested backtracking factors;
- selected model-quality `rho`;
- provider route and finite-state flags.

No new candidate Newton direction or backtracking factor is introduced.

## Frozen local admissibility L0

An iteration is locally floor-admissible iff all hold:

1. `r_bal <= 10`;
2. `r_storage_ulp <= 10`;
3. `r_head <= 1`;
4. ponding is either not applicable or `r_pond <= 1`;
5. `z_h_inf <= 1e-8`;
6. no already tested backtracking factor improves the selected composite merit by more than 10%;
7. finite diagnostics;
8. provider route equals the frozen fixture route.

These are inherited NLGLOB05 quantities. They are not production convergence tolerances.

## Frozen trajectory certificate T0

Evaluate T0 at iteration k only when iterations k-2, k-1 and k are all present.

T0 is true iff:

### T0.1 Three-iteration persistence

All three iterations k-2:k satisfy L0.

### T0.2 Balance-floor stagnation

Across the three iterations:

- `max(r_bal) / max(min(r_bal), tiny) <= 4`; and
- terminal `r_bal(k) >= 0.75 * r_bal(k-2)`.

This requires the solve to remain inside one bounded floor neighborhood without a material downward trend. The factor 4 is a half-decade-scale persistence bound; 0.75 rejects trajectories still showing more than 25% net balance improvement over the window.

### T0.3 Persistent correction collapse

Across all three iterations:

`z_h_inf <= 1e-8`.

### T0.4 Repeated backtracking exhaustion

At least 2 of the 3 iterations satisfy the inherited NLGLOB05 no-material-improvement condition:

`best_tested_M >= 0.90 * selected_M`.

### T0.5 Model-quality evidence

At least 2 of the 3 selected iterations have:

`rho < 0.25`.

This retains the TIMEINT17I/NLGLOB02 poor-model attribution while allowing one noisy iteration.

### T0.6 Route/state continuity

All three iterations:

- are finite;
- retain the same intended dynamic-top route;
- have no provider or process failure.

T0 is an exhaustion discriminator only. It does not accept a physical state.

## Frozen positive population

For each of the 96 endpoint-failure trajectories, evaluate the final audited iteration as the positive terminal target.

A trajectory is terminal-certifiable when T0 is true at its final audited iteration.

## Mandatory negative controls

### N1 — early-trajectory control

All eligible evaluation points ending strictly earlier than the final two Newton iterations of each endpoint-failure trajectory.

This retains the NLGLOB05A early population as a mandatory control.

Frozen false-positive maximum:

`<= 5%`.

### N2 — adequate-model control

All eligible evaluation points whose terminal selected `rho >= 0.25`.

Frozen false-positive maximum:

`<= 5%`.

### N3 — above-floor control

Any eligible point whose terminal iteration has `r_bal > 10`.

T0 must reject 100%.

### N4 — storage-floor-absent control

Any eligible point whose terminal iteration has `r_storage_ulp > 10`.

T0 must reject 100%.

### N5 — head/ponding unresolved control

Any eligible point whose terminal iteration has `r_head > 1`, or applicable `r_pond > 1`.

T0 must reject 100%.

### N6 — route/nonfinite control

Any eligible point with route mismatch, nonfinite diagnostics, provider failure or process failure in the three-iteration window.

T0 must reject 100%.

## Frozen qualification gates

Classify:

`NLGLOB06_TRAJECTORY_EXHAUSTION_DISCRIMINATOR_QUALIFIED`

only if all hold:

1. complete 4 materials x 3 routes x 2 modes x 4 dt coverage;
2. 96 endpoint-failure trajectories available;
3. at least 90 terminal trajectories have a complete three-iteration diagnostic window;
4. terminal certification fraction >= 0.60;
5. certified terminal trajectories include TG and KLAG, all 3 routes, and at least 3 materials;
6. at least 4/6 route-mode families have terminal certification fraction >= 0.50;
7. N1 early false-positive fraction <= 0.05;
8. N2 adequate-model false-positive fraction <= 0.05;
9. N3-N6 false-positive fraction = 0;
10. no classification depends on changing solver thresholds or physical flux reconstruction.

If any N3-N6 control is accepted:

`NLGLOB06_TRAJECTORY_CERTIFICATE_UNSAFE`.

If N1 or N2 exceeds 5% while hard controls pass:

`NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`.

If terminal certification is below 25%:

`NLGLOB06_TRAJECTORY_CERTIFICATE_NOT_USEFUL`.

If coverage/diagnostics fail:

`BLOCKED_NLGLOB06_TRAJECTORY_COVERAGE`.

Otherwise:

`NLGLOB06_MIXED_TRAJECTORY_SIGNAL`.

## Consequence of a positive result

A positive P0 does not alter production convergence.

It authorizes a separately preregistered test-only endpoint replay using the frozen T0 rule plus the unchanged physical accepted-interval mass guard.

Only a physically admissible replay may return the research line to TIMEINT17 same-route dynamic-top qualification.

## Stop rules

Do not post-hoc tune within NLGLOB06:

- window length;
- factor-4 balance range;
- 0.75 balance-progress limit;
- `z_h_inf` threshold;
- 10% merit-improvement threshold;
- rho threshold or 2-of-3 rule;
- negative-control definitions.

A negative T0 result closes this certificate formulation. A materially different discriminator requires a separately preregistered successor.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected effect in P0: diagnostic only and compliant.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB06

BASELINE: `2332a59d2ec33245f53593960e0c334525eda148`

BRANCH: `research/f-pe-nlglob06-trajectory-exhaustion`

SCOPE: observational cross-iteration exhaustion discrimination

INTERFACES CHANGED: none

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement deterministic observational T0 harness on the frozen bank

RECOVERY POINT: this preregistration commit

DEPENDENCIES / BLOCKERS: replay remains blocked until T0 qualifies

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
