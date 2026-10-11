# F-PE-TIMEINT17E preregistration — static-route Newton/backtracking geometry attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17B: `TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`;
- TIMEINT17C: `TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`;
- TIMEINT17D: `TIMEINT17D_JACOBIAN_CONSISTENT_NONCONTRACTIVE`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Frozen question

Why does the shared static-route dynamic-top endpoint solve exhaust the nonlinear iteration envelope even though:

- the physical boundary route remains static;
- the dynamic-top provider remains available;
- provider derivatives match finite differences;
- the complete top-row residual/Jacobian matches finite differences?

TIMEINT17E distinguishes failure of the line-search contraction from failure of the post-step convergence gates.

No numerical behavior is changed.

## Exact current HeadCalc policy

For each nonlinear iteration, HeadCalc computes a Newton correction `delta_head`.

Backtracking starts with:

`factor = 1`

and tests up to `MaxBackTr=8` candidate steps.

After each candidate residual evaluation:

`sump = 0.5 * dot(F,F)`

`Fmax = max(abs(F))`.

The candidate exits backtracking when either:

`sump < sumold`

or

`Fmax < CritDevBalCp`.

Otherwise:

`factor = factor / 3`

and the next candidate is tested.

After backtracking, convergence is tested independently through:

1. compartment residual:
   `abs(F_i) <= CritDevBalCp`;
2. head-change criterion;
3. ponding-layer balance where applicable;
4. total balance:
   `abs(sum(F)) <= CritDevBalTot`.

TIMEINT17E observes these exact rules. It does not replace them.

## Frozen bank

Reuse the exact TIMEINT17A2 fixtures and settings.

Coverage:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- TG and matched KLAG;
- MAXIT=8;
- MaxBackTr=8;
- unchanged physical and numerical tolerances;
- unchanged dynamic-top provider;
- unchanged conductivity staging.

Primary attribution uses the terminal endpoint solve of each run.

## Test-only logging

Instrument a materialized HeadCalc only.

For every nonlinear iteration record before the linear solve:

- iteration index;
- `sumold`;
- initial `Fmax`;
- maximum absolute residual;
- current top head;
- current ponding.

After the Newton linear solve record:

- max absolute `delta_head`;
- L2 norm of `delta_head`.

For every backtracking candidate record:

- iteration index;
- backtracking try;
- factor actually used;
- candidate `sump`;
- candidate `Fmax`;
- `sump/sumold`;
- top head;
- ponding;
- dynamic-top route;
- whether the candidate satisfies the HeadCalc line-search exit condition.

After the convergence checks record:

- compartment-balance failure yes/no;
- head-change failure yes/no;
- ponding-balance failure yes/no;
- total-balance failure yes/no;
- `abs(sum(F))`;
- maximum normalized head change;
- ponding deviation where evaluated;
- whether the iteration converged.

Logging must not alter state, factor selection, residual, Jacobian or convergence decisions.

## Frozen per-trial derived metrics

For the terminal endpoint trial derive:

- number of nonlinear iterations;
- total backtracking candidates;
- number and fraction of iterations where full factor 1 is accepted;
- number and fraction requiring factor <1;
- number of iterations exhausting all backtracking tries without `sump < sumold` and without `Fmax < CritDevBalCp`;
- best residual reduction ratio per iteration;
- terminal residual reduction ratio relative to first iteration;
- dominant post-step convergence gate;
- repeated/stagnant residual indicator.

A residual iteration is `STAGNANT` when its best candidate satisfies:

`best_sump / sumold >= 0.99`.

A strong contraction iteration has:

`best_sump / sumold <= 0.5`.

## Frozen attribution classes

### BACKTRACK_NONDECREASE_DOMINANT

Classify:

`TIMEINT17E_BACKTRACK_NONDECREASE_DOMINANT`

if at least 75% of terminal endpoint failures contain one or more nonlinear iterations that exhaust all 8 backtracking candidates without satisfying the current line-search exit condition.

### STAGNATION_DOMINANT

Classify:

`TIMEINT17E_STAGNATION_DOMINANT`

if the previous condition does not hold and at least 75% of terminal endpoint failures have >=50% of their nonlinear iterations classified STAGNANT.

### POSTSTEP_GATE_DOMINANT

Classify:

`TIMEINT17E_POSTSTEP_GATE_DOMINANT`

if at least 75% of terminal endpoint failures show residual contraction in >=75% of nonlinear iterations but remain nonconverged primarily because one or more post-step gates fail.

Report the dominant gate separately:

- `COMPARTMENT_BALANCE`;
- `HEAD_CHANGE`;
- `PONDING_BALANCE`;
- `TOTAL_BALANCE`;
- `MIXED`.

### NEWTON_OVERSHOOT_WITH_RECOVERY

Classify:

`TIMEINT17E_NEWTON_OVERSHOOT_WITH_RECOVERY`

if at least 75% of endpoint failures reject the full Newton factor in >=50% of iterations but find a residual-reducing smaller factor in those iterations.

### MIXED_CONTRACTION_BLOCKER

Otherwise:

`TIMEINT17E_MIXED_CONTRACTION_BLOCKER`.

## Shared versus TG-specific attribution

Repeat the same census for matched KLAG endpoint failures.

If >=75% of TG terminal endpoint failures share the same E attribution class with KLAG:

`TIMEINT17E_SHARED_NEWTON_BLOCKER`.

Otherwise preserve a TG-specific signal.

## Stop rules

TIMEINT17E does not:

- change MAXIT;
- change MaxBackTr;
- change the factor schedule;
- change convergence tolerances;
- change dt or forcing;
- alter K staging;
- freeze a route;
- localize events;
- modify production `src/**`.

No repair is made inside E.

## Consequence

TIMEINT17E closes attribution only.

A separately preregistered successor may test a repair only after E identifies the dominant mechanism.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
