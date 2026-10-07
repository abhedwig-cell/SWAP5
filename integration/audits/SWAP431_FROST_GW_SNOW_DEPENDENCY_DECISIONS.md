# SWAP431 frost groundwater and snow dependency decisions

Date: 2026-10-07

This record narrows the two remaining MC-FROST01 items after the drainage-dependent cluster. It is a source-bound ownership decision, not an admission or a replacement for qualification.

## SW431-FROST-GW

B1.11 orders the lower-boundary and frost operations explicitly:

1. `BoundBottom` resolves the active lower-boundary route and assigns `qbot`.
2. `BoundBottom` stores that exact proposal in `qbot_nonfrozen`.
3. `FrozenBounds` starts from `qbot = qbot_nonfrozen`.
4. Only then can low-air/deep-frost logic set the bottom proposal to zero, transfer it into the deepest drainage level, or scale drainage by `1 + qbot/qdratot`.

Authority:
- `reference/swap-4.3.1/b1_11_frost_source/SWAP/boundbottom.f90`
- `reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90`

Therefore the missing capability is not a new bottom-boundary equation and not a generic frost multiplier. The required dependency is an **accepted bottom-proposal composition seam** that exposes the already-resolved non-frozen proposal to the existing frost owner before the hydraulic solve. Route-specific source resolvers for modes 2/3/4/5/7/8 remain owners of their own proposal semantics. Frost may transform the resolved proposal but must not reimplement those routes or mutate committed state post hoc.

Minimum future qualification must cover at least:
- unchanged non-frozen proposal when the low-air frost branch is inactive;
- deep-frost zero-bottom branch;
- drainage-present transfer/scaling branch;
- trial reject/retry regeneration from the same accepted pre-trial state;
- restart equivalence;
- one authoritative bottom/drainage mass ledger;
- preservation of each admitted lower-boundary route used in the matrix.

Disposition: **OPEN, SEPARATE DESIGN DEPENDENCY**. Do not reopen B19.

## SW431-FROST-SNOW

B1.11 execution order is also explicit:
- at day start `Snow(2, tsoil(1), tav, ...)` executes first;
- `FrozenCond(tsoil, tetop)` executes immediately afterwards;
- `tetop` is documented in `temperature.f90` as the soil-surface temperature **under snow cover**;
- soil temperature state is advanced later by `SoilTemperature(2)`.

Authority:
- `reference/swap-4.3.1/b1_11_frost_source/SWAP/swap.f90`
- `reference/swap-4.3.1/b1_11_frost_source/SWAP/temperature.f90`
- `reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90`

So the missing composition is not a drainage extension and cannot be closed by feeding air temperature directly into the existing frost geometry. The dependency is a **shared snow-insulated sensible-temperature owner** that materializes the source-faithful under-snow `tetop` used by both the thermal solve and frost geometry.

Minimum future qualification must establish:
- no-snow identity with the admitted sensible-temperature path;
- snow-covered `tetop` source semantics;
- day-boundary ordering;
- snow storage/melt preservation;
- frost-factor and frost-geometry response to the same under-snow temperature;
- retry/restart preservation of both snow and temperature continuation state.

Disposition: **OPEN, DEPENDS ON SW431-TEMP-SNOW / THERMAL OWNER**. It is not a blocker for MC-DRAIN01 closure.

## Canonical reconciliation

Canonical advanced from `4dc02866825c6bcd24de81944c2b39e5fb0ca878` to `75114770c4d4d300f9d8037207d5498fa0e1f44e` through crop/CO2-only paths. None intersects the drainage/frost dependency surface recorded in `SWAP431_DRAIN_FROST_CLUSTER_STATUS.json`. Existing focused local evidence is therefore inherited unchanged; integrated serialized qualification remains pending.
