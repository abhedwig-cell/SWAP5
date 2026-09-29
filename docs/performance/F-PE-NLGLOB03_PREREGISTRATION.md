# F-PE-NLGLOB03 preregistration — floor-aware convergence-contract discrimination

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ad1c4b9193238a46dff95bd30e251adfc0426302`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- NLGLOB02: `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`;
- BALTOL02: effective Reference balance-rate floor `max(configured, 2.8e-16 cm / dt)`.

## Purpose

Before changing the nonlinear convergence contract, identify whether the NLGLOB02 near-floor failures are dominated by:

1. a compartment-scale residual that remains physically/numerically unresolved;
2. total-balance summation/cancellation at floating-point resolution;
3. both;
4. neither.

This phase is observational only.

No failed endpoint is reclassified as converged.

No acceptance threshold is changed.

## Literature guard

Termination criteria for Richards correctors require explicit protection against premature termination when nonlinear residual information and Jacobian quality disagree. A small Newton correction alone is not sufficient evidence of convergence.

General nonlinear-PDE stopping criteria likewise distinguish algebraic error from discretization/physical error and stop only when further nonlinear work no longer materially affects the relevant solution error.

Therefore NLGLOB03 does not begin by inventing a relaxed residual threshold. It first attributes the attainable residual structure.

## Frozen bank

Reuse exactly the NLGLOB02 bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged A2 route-margin fixtures;
- MAXIT = 8;
- MaxBackTr = 8;
- unchanged residual equations;
- unchanged analytic Jacobian;
- unchanged K staging;
- unchanged dynamic-top provider;
- unchanged convergence thresholds.

Only terminal endpoint-failure nonlinear iterations are interpreted.

## P0 diagnostics

At every audited Newton origin, preserve the NLGLOB02 diagnostics and additionally emit the complete active residual vector:

`R_i, i=1..NN`.

Offline, compute:

- `sum_naive = sum(R_i)` in the same ordinary binary64 ordering represented by the emitted vector;
- `sum_fsum = math.fsum(R_i)` using compensated/high-accuracy summation;
- `sum_abs = sum(|R_i|)`;
- `r_tot_naive = |sum_naive| / tol_tot`;
- `r_tot_fsum = |sum_fsum| / tol_tot`;
- `r_cp = max_i |R_i| / tol_cp`;
- cancellation ratio `c_sum = |sum_naive-sum_fsum| / max(|sum_naive|, tol_tot)`;
- conditioning proxy `kappa_sum = sum_abs / max(|sum_fsum|, tol_tot)`.

No compensated value is fed back into the solver.

## Frozen subsets

Primary subset:

- selected rho < 0.25;
- NLGLOB02 `r_bal <= 10`.

Secondary comparator:

- selected rho >= 0.25.

Terminal case diagnostics are computed separately from all audited iterations.

## Frozen classifications

### TOTAL_BALANCE_SUMMATION_SIGNAL

`NLGLOB03_TOTAL_BALANCE_SUMMATION_SIGNAL`

if coverage passes and all hold:

1. total balance is the dominant balance component in >=50% of the primary subset;
2. in >=25% of total-dominant primary iterations, compensated summation moves `r_tot` by at least 25%;
3. in >=10% of total-dominant primary iterations, `r_tot_naive > 1` while `r_tot_fsum <= 1`;
4. the direction is present in at least 4/6 route-mode families.

### COMPARTMENT_FLOOR_SIGNAL

`NLGLOB03_COMPARTMENT_FLOOR_SIGNAL`

if:

1. compartment balance dominates >=50% of the primary subset;
2. median primary `r_cp <= 10`;
3. compensated total summation does not satisfy the total-balance signal above.

### MIXED_BALANCE_FLOOR_STRUCTURE

`NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`

if neither component reaches 50% dominance but each contributes >=25%, or if the total-summation signal is substantial but does not satisfy all four total-balance gates.

### NO_SUMMATION_OR_COMPARTMENT_ATTRIBUTION

`NLGLOB03_NO_SIMPLE_BALANCE_FLOOR_ATTRIBUTION`

if:

- compensated summation rarely changes the total residual materially;
- compartment residuals remain above the floor in most primary iterations;
- neither structured signal above applies.

## Coverage gate

Conclusive P0 requires:

- all 3 routes;
- all 4 materials;
- all 4 dt levels;
- TG and KLAG;
- >=500 audited failing Newton iterations;
- >=100 poor-model near-floor iterations;
- residual vectors present for >=99% of audited iterations;
- vector length equal to active node count for every accepted record.

Otherwise:

`BLOCKED_NLGLOB03_RESIDUAL_VECTOR_COVERAGE`.

## Consequence rules

If `TOTAL_BALANCE_SUMMATION_SIGNAL`:

- do not relax total-balance tolerance;
- open a separately preregistered numerically stable total-balance evaluation experiment;
- candidate techniques may include compensated/pairwise summation, but only as numerical evaluation changes;
- physical mass accounting remains unchanged.

If `COMPARTMENT_FLOOR_SIGNAL`:

- do not change total-balance summation;
- investigate attainable local residual precision and constitutive/storage cancellation at the dominant nodes.

If mixed:

- decompose by route/material/node before any convergence-contract candidate.

If no simple attribution:

- do not create a floor-aware acceptance rule;
- return to alternative globalization/linearization families under separate preregistration.

## Explicit prohibition

P0 does not authorize:

- accepting `r_bal <= 10`;
- multiplying BALTOL02 by any factor;
- weakening physical interval mass closure;
- changing head tolerance;
- changing MAXIT or backtracking;
- changing dt;
- changing route/event logic;
- production source edits.

## Architecture invariants

Affected invariants:

- 7 transactional timesteps;
- 13 mass conservation is absolute;
- 23 physical options separate from numerical policy;
- 25 reference mode remains available;
- 26 diagnostics are part of runtime;
- 30 explicit review of solver changes.

Expected effect: observational only, compliant.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
