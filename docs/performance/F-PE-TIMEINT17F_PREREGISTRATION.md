# F-PE-TIMEINT17F preregistration — route-specific nonlinear failure localization

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17D: `TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`;
- TIMEINT17E: `TIMEINT17E_MIXED_CONTRACTION_BLOCKER`;
- TIMEINT17E secondary: `TIMEINT17E_TG_SPECIFIC_NEWTON_SIGNAL`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Motivation

TIMEINT17E showed that the aggregate mixed nonlinear classification is route-structured:

- FLUX is dominated by backtracking nondecrease/stagnation;
- HEAD and RUNOFF more often find residual-reducing candidates but remain nonconverged through post-step gates.

TIMEINT17F localizes those route-specific failures spatially and by convergence component.

It does not change solver behavior.

## Frozen bank

Reuse exactly the TIMEINT17A2 bank and settings:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- TG and matched KLAG;
- MAXIT=8;
- MaxBackTr=8;
- unchanged convergence tolerances;
- unchanged fixed-K staging;
- unchanged dynamic-top provider.

Primary analysis uses terminal `ENDPOINT_SOLVE_FAILURE` calls only.

## Additional logging

Extend the logging-only HeadCalc materialization.

For every backtracking candidate record:

- maximum absolute residual;
- node index of maximum absolute residual;
- residual at top node;
- residual at bottom node;
- total residual sum;
- existing iteration/try/factor/sump/ratio/route fields.

For every post-step convergence record:

- maximum residual node;
- top residual;
- bottom residual;
- total residual sum;
- maximum normalized/absolute head-change node;
- maximum head-change magnitude;
- ponding-balance deviation when evaluated;
- compartment-balance fail;
- head-change fail;
- ponding-balance fail;
- total-balance fail.

No residual component is modified by logging.

## FLUX localization classes

For terminal TG FLUX failures, classify each trial by the dominant node among:

- TOP: node 1;
- INTERIOR: nodes 2..NN-1;
- BOTTOM: node NN.

Use the best-residual candidate from each nonlinear iteration.

Aggregate:

### FLUX_TOP_RESIDUAL_DOMINANT

if >=75% of TG FLUX endpoint failures have TOP as dominant location in >=50% of their nonlinear iterations.

### FLUX_INTERIOR_RESIDUAL_DOMINANT

analogous for INTERIOR.

### FLUX_BOTTOM_RESIDUAL_DOMINANT

analogous for BOTTOM.

Otherwise:

`TIMEINT17F_FLUX_DISTRIBUTED_RESIDUAL`.

## HEAD/RUNOFF localization

For HEAD and RUNOFF terminal failures, inspect post-step gates after residual-reducing candidates.

Per trial count active gates and localize compartment-balance failures by max-residual node.

Aggregate separately by route.

### TOP_COMPARTMENT_GATE

if >=75% of endpoint failures for a route show compartment-balance failure and TOP is the max-residual location in >=50% of nonconverged iterations.

### INTERIOR_COMPARTMENT_GATE

analogous for INTERIOR.

### PONDING_GATE

if ponding-balance failure is active in >=75% of route failures.

### TOTAL_GATE

if total-balance failure is active in >=75% of route failures without a dominant compartment location.

Otherwise classify the route:

`DISTRIBUTED_POSTSTEP_GATE`.

## TG versus KLAG localization

Repeat the same localization for matched KLAG failures.

If >=75% of matched TG/KLAG pairs share the same dominant residual location and dominant post-step gate category:

`TIMEINT17F_SHARED_LOCALIZATION`.

Otherwise:

`TIMEINT17F_TG_KLAG_LOCALIZATION_DIVERGENCE`.

## Frozen outputs

Report:

- per-route dominant residual-node counts;
- per-material residual-node counts;
- per-route gate frequencies;
- top/bottom/max residual magnitudes;
- ponding deviation distribution;
- TG/KLAG matched localization fraction;
- route-specific classification.

## Stop rules

TIMEINT17F does not:

- change a tolerance;
- change MAXIT or MaxBackTr;
- change line-search factors;
- change timestep;
- alter dynamic-top equations;
- alter K staging;
- localize route events;
- modify production `src/**`.

No repair belongs inside F.

## Consequence

F may nominate one narrowly scoped repair workunit only if the localization is stable across at least three materials and three dt levels within the affected route.

Otherwise TIMEINT17 closes the dynamic-top acceleration attempt as unresolved nonlinear robustness research.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
