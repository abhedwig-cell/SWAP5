# F-PE-NLGLOB05A preregistration — floor-aware nonlinear convergence certificate discrimination

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
- BALTOL02 production authority remains unchanged.

## Purpose

Determine whether the terminal endpoint-failure states in the frozen TIMEINT17 bank can be distinguished as numerically exhausted at the already qualified storage/balance representation floor while all non-balance parts of the existing nonlinear convergence contract are already satisfied.

This is an offline certificate discrimination experiment.

The solver is not allowed to terminate differently in NLGLOB05A.

## Existing convergence contract

Current HeadCalc convergence requires, among other relevant items:

1. every compartment residual:
   `|R_i| <= CritDevBalCp`;
2. total residual:
   `|sum_i R_i| <= CritDevBalTot`;
3. pressure-head update:
   - if `|h_old| < 1 cm`, `|h-h_old| <= CritDevh2Cp`;
   - otherwise `|h-h_old|/|h_old| <= CritDevh1Cp`;
4. where applicable, ponding-layer balance:
   `|deviat_pond| <= CritDevPondDt`.

NLGLOB05A does not alter items 3 or 4.

## Frozen bank

Reuse the exact NLGLOB02-04/TIMEINT17 endpoint-failure bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged A2 fixtures;
- MAXIT=8;
- MaxBackTr=8;
- unchanged dynamic-top provider;
- unchanged K staging;
- unchanged BALTOL02;
- unchanged head and ponding tolerances.

## New diagnostic contract

At every post-backtracking Newton iteration record:

### Head contract ratio

For each active node:

- if `|h_old| < 1 cm`:
  `r_head_i = |h-h_old| / CritDevh2Cp`;
- else:
  `r_head_i = (|h-h_old|/|h_old|) / CritDevh1Cp`.

Record:

`r_head = max_i r_head_i`.

The current head-update contract is satisfied iff `r_head <= 1`.

### Ponding contract ratio

For dynamic top, evaluate the same physical ponding balance expression used by HeadCalc:

`deviat_pond = pond-pondm1-net_potential_surface_flux*dt+runots-qtop*dt`.

Record:

`r_pond = |deviat_pond| / CritDevPondDt`.

For FLUX cases where ponding balance is not physically active, mark `pond_applicable=false` and do not use `r_pond` as a gate.

### Existing floor evidence

Join each iteration to NLGLOB04 diagnostics:

- `r_bal`;
- dominant-node `r_storage_ulp`;
- dominant-node identity;
- selected rho and selected factor.

## Frozen candidate certificate C0

A post-backtracking iteration is `C0_CERTIFIED` iff all hold:

1. `r_bal <= 10`;
2. dominant-node `r_storage_ulp <= 10`;
3. `r_head <= 1`;
4. ponding contract is either not applicable or `r_pond <= 1`;
5. all state and diagnostic quantities are finite;
6. current provider route equals the frozen target route;
7. the iteration is not the first Newton iteration.

The factor 10 is inherited from the preregistered one-decade floor neighborhood used by NLGLOB02-04. It is not a new solver tolerance and is not proposed for production acceptance.

## Positive population

For each terminal `ENDPOINT_SOLVE_FAILURE` case, the positive target is the final audited Newton iteration.

A terminal case is a `CERTIFIABLE_TERMINAL` when its final audited iteration satisfies C0.

## Negative controls

The following are independent negative controls.

### NC1 — above-floor iterations

Any audited iteration with `r_bal > 10`.

C0 must reject 100%.

### NC2 — head-unresolved iterations

Any audited iteration with `r_head > 1`.

C0 must reject 100%.

### NC3 — ponding-unresolved iterations

Any iteration where ponding balance is applicable and `r_pond > 1`.

C0 must reject 100%.

### NC4 — early iterations

For each terminal-failure solve, all audited iterations strictly earlier than the final two Newton iterations.

C0 false-positive fraction must be <=1%.

This control is intentionally independent of rho.

### NC5 — storage-floor absent

Any iteration with `r_storage_ulp > 10`.

C0 must reject 100%.

## Frozen qualification gates

NLGLOB05A qualifies C0 as a research convergence certificate only if:

1. all bank coverage passes;
2. >=75% of terminal endpoint-failure cases are CERTIFIABLE_TERMINAL;
3. the terminal-certifiable direction holds in >=4/6 route-mode families, with each such family >=60% terminal certification;
4. NC1 rejection = 100%;
5. NC2 rejection = 100%;
6. NC3 rejection = 100%;
7. NC4 false-positive fraction <=1%;
8. NC5 rejection = 100%;
9. no nonfinite diagnostics;
10. no route-mismatch iteration is certified.

If all pass:

`NLGLOB05A_FLOOR_CERTIFICATE_DISCRIMINATION_QUALIFIED`.

If terminal coverage is <25%:

`NLGLOB05A_FLOOR_CERTIFICATE_NOT_USEFUL`.

If any hard negative-control gate NC1/NC2/NC3/NC5 or route consistency fails:

`NLGLOB05A_FLOOR_CERTIFICATE_UNSAFE`.

Otherwise:

`NLGLOB05A_MIXED_CERTIFICATE_SIGNAL`.

## Consequence

A positive A result does not change production convergence.

It authorizes only a separately preregistered NLGLOB05B test-only replay in which C0 may terminate the endpoint solve, followed by unchanged physical interval mass and dynamic-top trajectory qualification.

A negative A result closes this specific floor-aware certificate.

## Explicit prohibitions

NLGLOB05A does not:

- change production `src/**`;
- change BALTOL02;
- change head or ponding tolerances;
- change MAXIT, backtracking, dt or K staging;
- change dynamic-top route semantics;
- weaken physical mass acceptance;
- call C0 production convergence.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: diagnostic only, compliant.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
