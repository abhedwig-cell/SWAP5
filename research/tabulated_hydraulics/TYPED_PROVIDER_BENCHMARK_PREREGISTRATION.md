# TAB-HYD typed-provider benchmark preregistration

Date: 2026-09-20

Status: **preregistered research experiment; implementation not yet admitted**

## Research question

If the bounds-safe raw-head400 representation closes its constitutive and transfer-envelope gates, does implementing that representation behind SWAP5's existing typed `constitutive_hydraulics_provider_t` produce a material runtime reduction for the currently admitted `SWKIMPL=0` Reference Richards route?

This is a different question from the legacy `SWSOPHY=1` benchmark because the typed provider ABI evaluates theta, C and K together as vectors.

## Authority and scope

Production/reference authority:

- current canonical at preregistration: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- frozen scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`;
- analytical provider: `src/solver/mod_b110_default_mvg_provider.f90`;
- provider ABI: `src/solver/mod_soil_water_solver_contract.f90`;
- Reference Richards typed call pattern: `src/legacy/b1_10_port/headcalc.f90`;
- production binding: `src/adapter/mod_b110_production_soil_water_task2.f90`.

Research representation authority is the **bounds-safe** raw-head400 result only. Pre-fix raw-head evidence is not admissible.

## Frozen candidate semantics

The candidate must preserve the representation already under qualification:

- 400 physical pressure-head knots generated from the admitted default-MvG relation;
- raw pressure head `h` as interpolation coordinate;
- `ln(K)` as conductivity ordinate;
- explicit analytical wet theta/C continuation;
- explicit Ksat plateau and its boundary semantics;
- constant dry extension;
- no tolerance-based state reuse;
- no change to Richards residual, convergence, transaction or retry policy.

The typed-provider experiment may fuse work that the provider ABI already requests together, for example:

- locate the raw-head interval once per node;
- evaluate theta and C from the same interval data;
- evaluate ln(K)/K from the same physical interval when valid;
- reuse immutable preprocessing coefficients.

It may **not** alter table knots, acceptance tolerances or physical branch locations in response to benchmark results.

## First experiment: provider-only cost

Compare:

A. current `b110_default_mvg_provider_t`;

B. research raw-head400 typed provider.

Use identical vectors of pressure heads covering the state range observed in the existing Hupsel and transfer-envelope cases. Include repeated changing-head sequences rather than benchmarking one permanently cached vector.

Report:

- wall-clock cost per vector evaluation;
- cost per active node;
- theta/C/K maximum differences;
- allocation count or proof of no per-call allocation;
- preprocessing cost separately from repeated evaluation cost.

Use balanced A/B/A or B/A/B blocks. Do not claim a sub-percent difference when run-order noise is of comparable magnitude.

## Second experiment: Reference Richards integration

Only if provider-only fidelity is acceptable, inject the research provider through the existing request-level constitutive seam in a **research harness**. Do not add production Task-2 selection yet.

Run the existing K0 hydrological transfer envelope with the same physical forcing/boundary cases used by TAB-HYD.

Required scientific result:

- all previously preregistered trajectory metrics remain inside the existing TAB-HYD acceptance envelope;
- no change in accepted/retried step semantics;
- no mass or state-ownership regression.

Performance result:

- use order-balanced or A/B/A repeated timing;
- report every scenario, not only Hupsel;
- report analytical and table medians plus paired deltas;
- treat effects smaller than observed order/noise spread as parity, not speedup.

## Deliberate exclusions

This experiment does not admit or test:

- generic user-supplied table input;
- legacy `SWSOPHY=1` file compatibility;
- `SWKIMPL=1` production;
- hysteresis;
- modified/bimodal/exponential hydraulic models;
- inverse pressure-head tables;
- frost/macropore extensions;
- a portable whole-model or MultiSWAP speed guarantee.

## Decision rule

After the bounds-safe raw-head research gates close:

- if typed K0 remains at parity within timing noise, close the table-acceleration hypothesis for the current admitted MvG/K0 route as **scientifically feasible but not a demonstrated production acceleration**;
- if typed K0 shows a repeatable material reduction across the transfer envelope, proceed to a separately owned production-provider work unit;
- if fidelity fails, retain the analytical provider and close/reformulate the acceleration candidate before any production work.

No production implementation is authorized by this preregistration.
