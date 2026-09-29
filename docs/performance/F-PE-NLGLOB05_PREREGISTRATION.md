# F-PE-NLGLOB05 preregistration — floor-aware nonlinear convergence certificate

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@01adcb51992615e7a09016f1ce63a244c40acf3c`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- NLGLOB02: `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`;
- NLGLOB03: `NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`;
- NLGLOB04: `NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`;
- BALTOL02: qualified effective balance-rate floor `max(configured, 2.8e-16 cm / dt)`.

## Purpose

NLGLOB05 asks whether the late-iteration endpoint failures can be separated into:

1. **numerically exhausted, otherwise physically resolved states**, for which further Newton work is unable to improve the balance because the dominant residual is already at the qualified storage-representation floor; and
2. **genuinely unresolved states**, which must continue to be rejected.

This workunit first qualifies an observational certificate.

It does not yet modify the solver convergence decision.

A positive observational discriminator is required before any test-only acceptance replay.

## Principle

A small Newton update alone is not sufficient.

A near-floor balance alone is not sufficient.

A storage-ULP signal alone is not sufficient.

The certificate must require all relevant evidence simultaneously:

- BALTOL02-near balance state;
- dominant residual at the theta/storage representation floor;
- collapsed Newton correction;
- no material progress available from the tested backtracking candidates;
- existing head-update convergence;
- finite and route-consistent state;
- no physical interval mass anomaly in the enclosing trial;
- rejection of explicit negative controls.

The certificate therefore represents **evidence of numerical exhaustion**, not a relaxed tolerance.

## Frozen bank

Positive/discrimination bank:

Reuse the exact NLGLOB04 / TIMEINT17 endpoint-failure bank:

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
- unchanged BALTOL02;
- unchanged head and ponding criteria.

No case is removed after observing the certificate outcome.

## Frozen certificate C0

Evaluate C0 at each terminal endpoint-failure Newton iteration.

C0 is true only when **all** conditions below hold.

### C0.1 Balance neighborhood

Both:

`r_cp = max_i |R_i| / tol_cp <= 10`

and

`r_tot = |sum_i R_i| / tol_tot <= 10`.

The factor 10 is not an acceptance tolerance.

It is the already qualified NLGLOB02 observational near-floor band and may only be used as one necessary certificate input.

### C0.2 Storage representation exhaustion

At the dominant residual node:

`r_storage_ulp <= 10`

using the exact NLGLOB04 definition:

`storage_ulp_rate = (ulp(theta)+ulp(theta_m1))*fraction*dz/dt`.

### C0.3 Collapsed Newton correction

Require:

`z_h_inf <= 1e-8`.

Here:

`z_h_inf = max_i |delta_h,i| / max(1 cm, |h_i|)`.

This threshold is frozen before C0 outcomes.

It is deliberately much smaller than the existing head convergence scale and is used only to identify numerical exhaustion.

### C0.4 Existing head-update contract

For the backtracking candidate selected by the current solver, require:

`M_H <= 1`

where `M_H` is the existing TIMEINT17H normalized head-update convergence measure derived from the unchanged SWAP head tolerances.

Thus C0 never overrides an unresolved head update.

### C0.5 No material tested backtracking improvement

Let `M(f)` be the frozen TIMEINT17H composite diagnostic merit for every already tested factor in the terminal Newton iteration.

Require:

`min_f M(f) >= 0.90 * M(selected)`.

Equivalently, no tested factor offers >10% composite-merit improvement over the current selected candidate.

No new factors are introduced by NLGLOB05.

### C0.6 Finite state and route consistency

Require:

- all logged residual, head-step, storage-floor and merit diagnostics finite;
- dynamic-top route emitted at the terminal iteration equals the intended frozen fixture route;
- no route-transition terminal reason;
- no provider-unavailable or nonfinite failure.

### C0.7 Physical trial mass guard

The observational endpoint certificate does not itself publish a state.

For the later replay phase, any C0-certified state may only be accepted if the enclosing candidate trial independently satisfies the unchanged physical accepted-interval mass gate:

`|ledger_physical| <= 5e-8 cm`.

P0 therefore records whether sufficient state exists to evaluate this guard during replay.

No storage-derived external flux may be used.

## Frozen positive population

The positive candidate population is the NLGLOB04 primary set at terminal failure:

- selected rho < 0.25;
- `r_bal <= 10`.

C0 is expected to select a strict subset, not necessarily all primary iterations.

## Frozen negative controls

NLGLOB05 must evaluate C0 against all of the following controls.

### N1 — adequate-model iterations

All audited iterations with:

`selected rho >= 0.25`.

C0 should rarely trigger because these iterations are not the identified poor-model stagnation population.

### N2 — above-floor failing iterations

All audited failing iterations with:

`r_cp > 10` or `r_tot > 10`.

By construction C0 must reject 100%.

### N3 — storage-not-exhausted iterations

Audited failing iterations with:

`r_storage_ulp > 10`.

By construction C0 must reject 100%.

### N4 — unresolved head-update iterations

Audited failing iterations with selected:

`M_H > 1`.

By construction C0 must reject 100%.

### N5 — route/provider pathological cases

Any case with route mismatch, transition, provider unavailability, nonfinite diagnostic or process failure.

C0 must reject 100%.

## Frozen discrimination gates

P0 classifies:

`NLGLOB05_FLOOR_CERTIFICATE_DISCRIMINATOR_QUALIFIED`

only if all hold:

1. coverage includes all 3 routes, 4 materials, 4 dt levels, TG and KLAG;
2. >=500 audited failing Newton iterations;
3. >=100 primary poor-model near-floor iterations;
4. all required C0 diagnostics available and finite for >=99% of audited terminal-failure iterations;
5. C0 certifies >=50% of the primary population;
6. C0 certifies >=25 cases in each of TG and KLAG;
7. C0-certified primary cases span all 3 routes and at least 3 materials;
8. false-positive rate in N1 <=5%;
9. N2, N3, N4 and N5 false-positive rate = 0%;
10. no certificate decision depends on changing a solver threshold or recomputing physical fluxes from storage.

If primary coverage is adequate but C0 selects <50%:

`NLGLOB05_CERTIFICATE_TOO_NARROW`.

If any N2-N5 hard negative control is accepted:

`NLGLOB05_CERTIFICATE_UNSAFE`.

If N1 false-positive rate exceeds 5%:

`NLGLOB05_CERTIFICATE_NONSPECIFIC`.

If diagnostics/coverage fail:

`BLOCKED_NLGLOB05_CERTIFICATE_COVERAGE`.

## P1 — test-only acceptance replay

P1 executes only after:

`NLGLOB05_FLOOR_CERTIFICATE_DISCRIMINATOR_QUALIFIED`.

P1 is separately result-bearing but uses the already frozen C0 rule unchanged.

### Replay rule

At the point where canonical HeadCalc would otherwise return endpoint non-convergence after exhausted iterations, a test-only wrapper may publish the terminal candidate **only if C0 is true and the independent physical trial mass guard passes**.

No residual tolerance is changed.

No extra Newton iteration is added.

No new backtracking factor is tried.

The acceptance reason must be explicitly diagnosed as:

`NUMERICAL_FLOOR_CERTIFICATE`.

### P1 positive gate

The replay advances only if:

1. >=80% of previously failing endpoint trajectories complete;
2. both TG and KLAG improve completion;
3. all three routes are represented among recovered trajectories;
4. max accepted-interval physical ledger <=5e-8 cm;
5. cumulative physical ledger <=5e-8 cm;
6. no nonfinite state;
7. no route mismatch is newly accepted;
8. accepted states remain within the fine/reference envelope already used in TIMEINT17 where such a comparator exists;
9. work does not increase materially, because the certificate replaces futile termination rather than adding solves.

Positive:

`QUALIFIED_FLOOR_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`.

If C0 discriminates offline but P1 fails physical mass or state authority:

`CLOSED_FLOOR_CERTIFICATE_REPLAY_NOT_PHYSICALLY_ADMISSIBLE`.

If replay recovers too little:

`CLOSED_FLOOR_CERTIFICATE_REPLAY_INSUFFICIENT`.

## Return to TIMEINT17

Only after positive P1 may the research line return to TIMEINT17 same-route dynamic-top qualification.

Event localization remains blocked until same-route dynamic-top mechanism qualification becomes positive.

TIMEINT18 variable-step/LTE remains downstream.

## Explicit prohibitions

NLGLOB05 does not authorize:

- changing BALTOL02;
- accepting every `r_bal <= 10` state;
- weakening physical mass closure;
- ignoring head convergence;
- changing ponding physics;
- changing MAXIT or MaxBackTr;
- changing dt or K staging;
- dynamic-top event localization;
- production source changes before separate admission.

## Architecture invariants

Affected invariants:

- 7 transactional time steps;
- 13 mass conservation is absolute;
- 23 physical options remain separate from numerical policy;
- 24 predictable computational cost;
- 25 reference mode remains available;
- 26 diagnostics are part of runtime;
- 30 explicit review of solver changes.

Expected effect in P0: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB05

BASELINE: `01adcb51992615e7a09016f1ce63a244c40acf3c`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT EXPENSIVE ACTION: build observational C0 replay harness on the frozen NLGLOB04 bank

RECOVERY POINT: this preregistration commit

DEPENDENCIES / BLOCKERS: P1 blocked until P0 discriminator qualifies

## Production boundary

Research-only.

`LEGACY_NUMERICS` remains production default.
