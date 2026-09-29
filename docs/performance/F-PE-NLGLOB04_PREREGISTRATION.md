# F-PE-NLGLOB04 preregistration — residual-term cancellation and storage representation floor attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a409df7572018969f0e73a05696c402edd2363c2`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- NLGLOB02: `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`;
- NLGLOB03: `NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`;
- BALTOL02: qualified effective balance-rate floor `max(configured, 2.8e-16 cm / dt)`.

## Purpose

NLGLOB04 determines whether the late-iteration near-floor residual is produced by:

1. cancellation while summing the already formed local residual terms;
2. finite representation of the storage increment `theta - thetam1`;
3. another term-formation mechanism.

This remains observational. No convergence rule is changed.

## Frozen bank

Reuse exactly the NLGLOB02/03 endpoint-failure bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- A2 route-margin fixtures;
- MAXIT=8;
- MaxBackTr=8;
- unchanged dynamic-top provider;
- unchanged K staging;
- unchanged BALTOL02 floor;
- unchanged head and ponding tolerances.

Only terminal endpoint-failure nonlinear iterations are interpreted.

## Exact local residual terms

For each active node, record the terms exactly as assembled by current `vector_F`.

For the frozen bank, sources/sinks and macropore exchange are zero and bottom mode is zero flux.

### Top node

Record:

- `storage = (theta-theta_m1)*fraction*dz/dt`;
- `internal_lower = Kmean(2)*gradient(2)`;
- `top_bc`:
  - head route: `-Kmean(1)*gradient(1)`;
  - flux route: `qtop`;
- `source_sink = sink-source+root_sink`.

Then:

`R_1 = storage + internal_lower + top_bc + source_sink`.

### Interior node

Record:

- `storage`;
- `upper = -Kmean(i)*gradient(i)`;
- `lower = +Kmean(i+1)*gradient(i+1)`;
- `source_sink`.

Then:

`R_i = storage + upper + lower + source_sink`.

### Bottom node

On the frozen zero-flux bottom bank:

`R_N = storage + upper + source_sink`.

The diagnostic reconstruction must match the emitted solver residual to <=1e-13 absolute or <=1e-12 relative, whichever is larger.

## Local compensated summation diagnostic

For every node compute offline:

- `R_naive`: ordinary binary64 left-to-right sum of the emitted terms;
- `R_fsum`: `math.fsum` of the same already formed terms;
- `term_sum_abs = sum(abs(term_j))`;
- `local_move = |R_naive-R_fsum| / max(|R_naive|, tol_cp)`.

At each iteration use the node with the largest solver residual magnitude as the dominant node.

## Storage representation diagnostic

Record `theta`, `theta_m1`, matrix fraction and `dz`.

Define an observational binary64 storage representation scale:

`storage_ulp_rate = (ulp(theta) + ulp(theta_m1)) * fraction * dz / dt`.

This is not a tolerance.

Define:

`r_storage_ulp = |R_dominant| / max(storage_ulp_rate, tiny)`.

Also record:

- `storage_abs = |storage|`;
- `flux_abs_sum = sum(abs(interface/boundary flux terms))`;
- cancellation condition number
  `kappa_local = sum(abs(all local terms)) / max(|R_dominant|, tol_cp)`.

## Frozen primary subset

Same as NLGLOB03:

- selected rho < 0.25;
- NLGLOB02 r_bal <= 10.

Comparator:

- selected rho >= 0.25.

## Frozen classifications

### LOCAL_TERM_SUMMATION_SIGNAL

`NLGLOB04_LOCAL_TERM_SUMMATION_SIGNAL`

if coverage passes and all hold:

1. >=25% of primary dominant-node residuals change by >=25% under local `fsum`;
2. >=10% cross from `|R_naive|/tol_cp > 1` to `|R_fsum|/tol_cp <= 1`;
3. the same direction appears in >=4/6 route-mode families, where family direction means:
   - median compensated local residual ratio is lower than median naive ratio; and
   - >=10% crossing fraction.

### STORAGE_REPRESENTATION_FLOOR_SIGNAL

`NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`

if local summation signal fails and all hold:

1. >=50% of primary dominant-node residuals have `r_storage_ulp <= 10`;
2. the corresponding fraction in the adequate subset is <= half the primary fraction;
3. median primary `r_storage_ulp <= 10`;
4. the primary-near-storage-floor direction holds in >=4/6 route-mode families.

### MIXED_TERM_FLOOR_SIGNAL

`NLGLOB04_MIXED_TERM_FLOOR_SIGNAL`

if neither full signal passes but:

- local summation movement >=10% in >=10% of primary records; or
- storage representation proximity `r_storage_ulp <=10` occurs in >=25% of primary records.

### NO_LOCAL_ARITHMETIC_FLOOR_SIGNAL

`NLGLOB04_NO_LOCAL_ARITHMETIC_FLOOR_SIGNAL`

otherwise.

## Coverage gate

Conclusive NLGLOB04 requires:

- all 3 routes;
- all 4 materials;
- all 4 dt levels;
- TG and KLAG;
- >=500 audited failing Newton iterations;
- >=100 primary iterations;
- complete term decomposition for >=99% of audited iterations;
- reconstruction equality for >=99% of emitted node records.

Otherwise:

`BLOCKED_NLGLOB04_TERM_DECOMPOSITION_COVERAGE`.

## Consequence rules

If local-term summation signal:

- do not relax tolerances;
- open a separately preregistered stable local residual accumulation experiment.

If storage representation floor signal:

- do not alter mass acceptance;
- open a convergence-certificate study tied to the already qualified BALTOL02 representational depth floor;
- the certificate must still prove physical interval mass closure and finite/consistent accepted state.

If mixed:

- decompose by node/material/route before any production convergence rule.

If no local arithmetic signal:

- do not pursue floor-aware termination;
- move to a different nonlinear formulation/globalization family.

## Explicit prohibitions

NLGLOB04 does not:

- change production `src/**`;
- change BALTOL02;
- accept r_bal <= 10;
- change mass closure;
- change head/ponding tolerance;
- change MAXIT, MaxBackTr, dt, K staging or route/event logic.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational, compliant.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
