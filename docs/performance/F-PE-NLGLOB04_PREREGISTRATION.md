# F-PE-NLGLOB04 preregistration — residual-term cancellation and attainable local precision attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a409df7572018969f0e73a05696c402edd2363c2`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- NLGLOB02: `NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL`;
- NLGLOB03: `NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`;
- BALTOL02: qualified effective Reference balance-rate floor `max(configured, 2.8e-16 cm / dt)`.

## Purpose

NLGLOB04 determines where the late-iteration near-floor residual is created.

NLGLOB03 excluded final residual-vector summation as the dominant cause. The remaining possibilities lie upstream in the individual compartment balance terms and their local cancellation.

This workunit is observational only.

It does not modify:

- residual equations;
- Jacobian;
- constitutive laws;
- boundary routing;
- K staging;
- timestep;
- nonlinear tolerances;
- MAXIT / backtracking;
- accepted-state mass semantics.

## Frozen bank

Reuse exactly the NLGLOB03 endpoint-failure bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and matched KLAG;
- dt: 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon: 0.001 d;
- unchanged A2 route-margin fixtures;
- MAXIT = 8;
- MaxBackTr = 8;
- unchanged dynamic-top provider;
- unchanged convergence gates.

Interpret only terminal endpoint-failure nonlinear iterations.

## P0 instrumentation

At every audited Newton origin, emit the active-node residual decomposition used to form each compartment balance.

For node `i`, define diagnostic terms with the same signs used in the assembled residual:

`R_i = S_i + U_i + L_i + Q_i + T_i`

where:

- `S_i` = storage-rate term;
- `U_i` = upper/interface contribution;
- `L_i` = lower/interface contribution;
- `Q_i` = source/sink contribution, including zero when inactive;
- `T_i` = explicit dynamic-top contribution not already represented by the generic interface term, zero outside the top node.

If current implementation algebra combines some terms before residual assembly, the instrumentation must expose an equivalent non-overlapping decomposition whose signed sum reproduces the exact assembled residual.

No term may be reconstructed from the final residual after the fact.

## Exact decomposition gate

For every emitted node record require:

`|R_i - (S_i+U_i+L_i+Q_i+T_i)| <= max(1e-14, 1e-10*sum_abs_terms)`

where:

`sum_abs_terms = |S_i|+|U_i|+|L_i|+|Q_i|+|T_i|`.

This gate verifies the instrumentation only. It is not a physical or solver tolerance.

## Frozen local cancellation diagnostics

For every valid node record compute:

- `term_max = max(|S_i|,|U_i|,|L_i|,|Q_i|,|T_i|)`;
- `term_sum_abs = sum_abs_terms`;
- `cancel_ratio = term_sum_abs / max(|R_i|, R_floor)`;
- `residual_fraction = |R_i| / max(term_sum_abs, R_floor)`.

Use:

`R_floor = 1e-300`

only to avoid division by zero in offline diagnostics.

Also record the two largest-magnitude signed terms and whether they oppose in sign.

## Frozen subsets

Primary subset:

- selected rho < 0.25;
- NLGLOB02 `r_bal <= 10`.

Adequate comparator:

- selected rho >= 0.25.

Within the primary subset analyze separately:

1. total-balance-dominant iterations from NLGLOB03;
2. compartment-balance-dominant iterations;
3. dominant-residual node at each iteration;
4. route / mode / material / dt families.

## Frozen questions

NLGLOB04 asks:

1. Are poor-model near-floor residuals produced by subtraction of much larger local terms?
2. Which term pairs dominate cancellation?
3. Is storage-vs-flux cancellation materially different between total-dominant and compartment-dominant subsets?
4. Do FLUX, HEAD and RUNOFF occupy distinct term-cancellation regimes?
5. Is the phenomenon shared by TG and KLAG?
6. Are the dominant cancellation nodes the same nodes that dominate the residual and Newton correction?

## Frozen classifications

### LOCAL_CANCELLATION_SIGNAL

`NLGLOB04_LOCAL_CANCELLATION_SIGNAL`

if coverage passes and all hold:

1. median `cancel_ratio` at dominant residual nodes in the primary subset is >= 1e6;
2. median primary `cancel_ratio` is at least 10x the adequate-subset median;
3. the same direction holds in at least 4/6 route-mode families;
4. at least 75% of primary dominant-node records have the two largest terms opposite in sign.

### STORAGE_FLUX_CANCELLATION_SIGNAL

`NLGLOB04_STORAGE_FLUX_CANCELLATION_SIGNAL`

if LOCAL_CANCELLATION_SIGNAL holds and, in at least 60% of primary dominant-node records, the largest opposing pair consists of storage versus one or more flux/boundary terms.

### ROUTE_SPECIFIC_CANCELLATION_SIGNAL

`NLGLOB04_ROUTE_SPECIFIC_CANCELLATION_SIGNAL`

if the aggregate local-cancellation gate fails but at least one route satisfies the LOCAL_CANCELLATION_SIGNAL conditions in both TG and KLAG while another route does not.

### NO_STRONG_LOCAL_CANCELLATION_SIGNAL

`NLGLOB04_NO_STRONG_LOCAL_CANCELLATION_SIGNAL`

if median primary dominant-node `cancel_ratio < 1e4` and no route-specific signal qualifies.

### MIXED

Otherwise:

`NLGLOB04_MIXED_LOCAL_PRECISION_STRUCTURE`.

## Coverage gate

Conclusive P0 requires:

- all 3 routes;
- all 4 materials;
- all 4 dt levels;
- TG and KLAG;
- >=500 audited failing Newton iterations;
- >=100 primary poor-model near-floor iterations;
- valid decomposition for >=99% of active-node records in audited iterations;
- exact decomposition gate pass for >=99.99% of emitted records;
- no instrumentation-induced process failures.

Otherwise:

`BLOCKED_NLGLOB04_TERM_DECOMPOSITION_COVERAGE`.

## Consequence rules

If `STORAGE_FLUX_CANCELLATION_SIGNAL`:

- do not relax convergence tolerances;
- open a separately preregistered arithmetic-evaluation experiment at the identified term formation sites;
- candidate techniques may include algebraically equivalent cancellation-resistant formulations or higher-precision diagnostics;
- physical equations and mass semantics remain unchanged.

If `LOCAL_CANCELLATION_SIGNAL` without storage/flux dominance:

- decompose the identified dominant term pair before selecting a repair.

If `ROUTE_SPECIFIC_CANCELLATION_SIGNAL`:

- do not introduce a global arithmetic repair;
- localize to the route-specific assembly path.

If `NO_STRONG_LOCAL_CANCELLATION_SIGNAL`:

- do not open arithmetic cancellation repair;
- return to convergence-contract/globalization alternatives under separate preregistration.

If mixed:

- preserve the subfamily decomposition and open only the narrowest supported successor.

## Literature guard

Richards literature supports mixed-form convergence criteria that protect physical mass while distinguishing nonlinear termination behavior. This does not authorize accepting unresolved residuals solely because Newton corrections are small.

NLGLOB04 therefore attributes local attainable precision before any stopping-rule change.

## Architecture invariants

Affected invariants:

- 7 transactional timesteps;
- 13 mass conservation is absolute;
- 23 physical options separate from solver policy;
- 25 reference mode remains available;
- 26 diagnostics are part of runtime;
- 30 explicit review of solver changes.

Expected effect: observational only, compliant.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No convergence or mass authority change.

`LEGACY_NUMERICS` remains production default.
