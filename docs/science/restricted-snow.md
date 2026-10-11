# Restricted one-call-daily Snow formulation

This page documents the exact bounded Snow formulation admitted for the frozen SWAP5 Status-A review baseline. The controlling scientific scope is the F-VQ16 qualification of the B1.10-compatible **one-call-daily** process, with later F-PM02 preservation on the unchanged Snow process blob.

It is not a general snow-model theory chapter. In particular, no subdaily, multi-day or arbitrary-duration scaling law is inferred from the daily implementation.

## State, forcing and parameters

The frozen Snow process owns two state quantities:

```text
snow_water_storage
liquid_water_storage
```

`snow_water_storage` is the component storage used by the qualified Snow mass contribution. `liquid_water_storage` tracks the retained liquid fraction within the snowpack and must not be added again as an independent whole-system water store. The implementation explicitly subtracts the previously retained liquid contribution before reconstructing the new total snowpack storage, which is why F-VQ16 prohibits double counting retained liquid water.

The process receives daily forcing for:

```text
snowfall_input
rain_on_snow_input
soil_surface_temperature
mean_air_temperature
potential_soil_evaporation
reduced_soil_evaporation
ponding_evaporation
```

and two Snow parameters relevant to this formulation:

```text
suppress_sublimation
melt_coefficient
```

All quantities on this page describe the frozen process contract. The page does not introduce new units, tolerances or parameter ranges beyond those already established by the qualified source and its surrounding SWAP contracts.

## Exact temporal admission

The process first rejects a non-positive interval. It then requires the interval duration to be bitwise equal to one legacy day:

```text
t1 - t0 == 1.0 day
```

in the exact representation used by the implementation.

This is a scientific admission boundary, not just an API restriction. The source-bound F-VQ16 qualification explicitly passes exact one-day calls and fails closed for subdaily and multi-day calls. Therefore the formulas below must not be rescaled by multiplying or dividing by an arbitrary `dt`.

## Evaporation and sublimation routing

At the start of the call, the three soil/surface evaporation quantities are copied from forcing to the Snow flux result.

When sublimation is not suppressed and committed snow water storage is positive, the process redirects the potential soil-evaporation demand to snow sublimation:

```text
sublimation = potential_soil_evaporation
potential_soil_evaporation = 0
reduced_soil_evaporation   = 0
ponding_evaporation        = 0
```

When that condition is not met, Snow sublimation remains zero and the incoming evaporation quantities are left on their original routes.

This routing is part of the bounded Snow/evaporation interface. It does not by itself redefine the independently documented ET or surface-evaporation formulations.

## Warm fresh-snow shortcut

A special retained legacy branch applies when all three conditions are true:

```text
soil_surface_temperature > 0.5
snow_water_storage       < 1.0e-6
snowfall_input           > 0
```

The fresh snowfall is then converted directly to melt:

```text
snow_water_storage = 0
melt               = snowfall_input
sublimation        = 0
```

This branch is preserved because it belongs to the independently qualified B1.10 behaviour. F-DOC23 does not reinterpret the `0.5` and `1.0e-6` thresholds as new universal Snow constants outside this source-bound formulation.

## Temperature-index and rain-on-snow melt

Outside the warm-fresh-snow shortcut, dry melt potential is calculated from mean air temperature with a zero-degree snow temperature reference:

```text
smelt = melt_coefficient * (mean_air_temperature - 0)
```

When rain on snow is positive, the liquid-water sensible heat contribution is converted to meltwater equivalent as

```text
smeltr = rain_on_snow_input * 4180 * (mean_air_temperature - 0) / 333580
```

where the frozen implementation uses `4180` for liquid-water heat capacity and `333580` for latent heat of melting.

Initial melt is then bounded below by zero:

```text
melt = max(0, smelt + smeltr)
```

The qualification establishes preservation of this exact implementation behaviour. It does not establish a broader energy-balance snow model.

## Retained liquid water and drainage

The Snow state update first removes the previously retained liquid contribution from the total snow-water store while applying snowfall, sublimation and initial melt:

```text
snow_water_storage =
    previous_snow_water_storage
  + snowfall_input
  - sublimation
  - melt
  - previous_liquid_water_storage
```

Rain on snow is added to the liquid store:

```text
liquid_water_storage = previous_liquid_water_storage + rain_on_snow_input
```

The maximum retained liquid amount is then set to seven percent of the current combined liquid-plus-snow quantity:

```text
maximum_liquid_storage = 0.07 * (liquid_water_storage + snow_water_storage)
```

Excess liquid drains from the snowpack:

```text
liquid_drainage = max(0, liquid_water_storage - maximum_liquid_storage)
liquid_water_storage = liquid_water_storage - liquid_drainage
```

The retained liquid fraction is folded back into total `snow_water_storage`, while drained liquid is added to the melt transfer:

```text
snow_water_storage = snow_water_storage + liquid_water_storage
melt = melt + liquid_drainage
```

This is why `liquid_water_storage` is not a second independent water amount for whole-system mass accounting. It is a partition of the qualified snowpack water state.

## Snow-deficit clamp

If the reconstructed snow water storage becomes negative, the process does not allow a negative committed Snow store. It computes the deficit

```text
snow_deficit = -snow_water_storage
snow_loss    = melt + sublimation
```

and proportionally reduces melt and sublimation by the same factor:

```text
melt        = (1 - snow_deficit / snow_loss) * melt
sublimation = (1 - snow_deficit / snow_loss) * sublimation
```

after which both Snow state quantities are reset to zero.

F-VQ16 includes a dedicated `snow_deficit_clamp` bitwise qualification case. F-DOC23 therefore documents this as retained source behaviour rather than replacing it with a smoother or newly derived limiter.

## Component mass accounting

For one admitted daily call, F-VQ16 qualifies the Snow component mass terms with no new scientific tolerance.

The component accounting is

```text
storage_change = storage_end - storage_start

residual = storage_change
         - (snowfall_input
            + rain_on_snow_input
            - sublimation
            - melt)
```

with the same arithmetic grouping as the source-bound qualification.

The physical classification is critical:

- `snowfall_input` is an external inflow to the Snow component;
- `rain_on_snow_input` is an external inflow to the Snow component;
- `sublimation` is an external outflow from the Snow component;
- `melt` is an **internal transfer** to the receiving surface or soil-water component;
- retained liquid water is already represented inside the Snow component storage and must not be counted a second time.

Accordingly, `melt` can leave the Snow component balance without being a loss from the whole SWAP water system. The receiving component must account for the same water once, not twice.

## Candidate state and transaction semantics

The process evaluates from committed Snow state into candidate Snow state. A candidate result is not authoritative merely because the process calculation completed.

F-PM02 preserves the restricted Snow route through checkpoint, trial, retry and commit behaviour. Rejected or failed trial state must not leak into committed Snow storage or accepted accounting. The same qualification also preserves serialized real-physics MultiSWAP execution for the admitted Snow composition, with a maximum of one simultaneous real-physics solve.

That is a composition claim. It does not admit parallel real-physics Snow execution.

## Qualification and preservation chain

The frozen production process is:

```text
src/process/mod_snow_process.f90
blob 54702d71b4c84dce2842813549bd14c57301a383
```

F-VQ16 independently verifies the exact B1.10 one-call-daily Snow behaviour against an independently recovered legacy source and requires bitwise identity with no new scientific tolerance. Its verified matrix includes normal snowpack, warm fresh snowfall, deficit clamp, suppressed sublimation, two-call continuation, component mass terms, exact one-day calls, fail-closed invalid durations and O0/O2 output identity.

F-PM02 later reuses that immutable scientific authority because the exact Snow process blob remains unchanged. Its current-canonical preservation additionally verifies the surrounding restricted runtime composition, including checkpoint/trial/retry/commit behaviour and serialized MultiSWAP execution.

The capability-level admission boundary remains summarized in [Restricted Snow capability](../capabilities/restricted-snow.md).

## What this page does not establish

This page does not claim:

- subdaily Snow physics;
- multi-day calls as an equivalent replacement for repeated qualified daily calls;
- arbitrary-duration `dt` scaling;
- a complete surface energy-balance snow model;
- a new melt law, retention law or deficit limiter;
- parallel real-physics admission;
- that melt is an external whole-system loss;
- that retained liquid water is additional to `snow_water_storage` in the whole-system ledger;
- EB, Ross/RossFast or new groundwater semantics;
- whole-application SWAP 4.3.1 versus SWAP5 equivalence.

## Authority map

The controlling F-DOC23 claim matrix is `integration/f-doc/F-DOC23_AUTHORITY_MATRIX.md`.

Primary authorities are the F-VQ16 scientific qualification and F-PM02 current-canonical preservation record, with the exact frozen implementation in scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`.

See also [Water balance, signs and units](water-balance-and-conventions.md), [Surface evaporation](surface-evaporation.md), [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md) and [Status-A traceability](../status-a/TRACEABILITY.md).
