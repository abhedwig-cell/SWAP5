# PPA-WU05-A5 P1/P2 source map — top partition and excess redistribution

Date: 2026-09-30

Status: `EXACT_B1_11_SOURCE_MAP / LOCAL_IMPLEMENTATION_NOT_STARTED`

## Exact source

Authority:

- exact B1.11 `macrorate.f90`;
- exact B1.11 `macropore.f90`;
- identities inherited from PPA-WU05-A1.

Primary source regions:

- `macrorate.f90:118-161` — potential top input;
- `macrorate.f90:207-242` — standard-route inflow limitation;
- `macrorate.f90:1275-1326` — kinematic-wave full-domain excess handling;
- `macrorate.f90:1338-1404` — cross-domain redistribution and remaining excess return;
- `macropore.f90:1325-1331` — accepted storage / macropore-domain mass bookkeeping.

## P1 — top-boundary partition

When macropores reach the soil surface (`IcTopMp == 1`), the source constructs total potential top input as:

`FlwInTopPot = QMpLatSs + ArMpSs * (NRaiDt + NIrd + Melt) * dt`.

This contains two physically distinct contributions.

### Vertical direct contribution

For each domain:

`FlwInTopVrtDmPot(id) = ArMpTpDm(id) * (NRaiDt + NIrd + Melt) * dt`.

This is the direct precipitation/irrigation/melt contribution over the active macropore top area of the domain.

### Lateral overland contribution

For each domain:

`FlwInTopLatDmPot(id) = ArMpTpDm(id)/ArMpTp * QMpLatSs`.

Thus `QMpLatSs` is distributed over domains proportional to their macropore top area.

The source comments identify `QMpLatSs` as lateral overland flow originating from matrix infiltration excess/runoff.

### Covering-layer case

When `IcTopMp > 1`:

- direct surface macropore top input is not used;
- vertical inflow is instead calculated through the covering layer from its hydraulic state and `KsatCovLay`;
- remaining top excess later triggers an explicit error rather than being returned through the surface lateral route.

## Standard-route capacity limitation

For `swmbf == 1` or non-main domains under `swmbf == 2`:

1. all potential domain inflows are summed;
2. all potential domain outflows are summed;
3. temporary domain storage is calculated;
4. a source-defined maximum storage is constructed;
5. when temporary storage exceeds that maximum, `FrFlwIn` proportionally reduces the incoming terms.

The reduced terms include:

- vertical top inflow;
- lateral top inflow;
- saturated interflow inflow;
- saturated matrix exfiltration.

Only the rejected **top** share is accumulated in:

`FlwInTopExcesTot`.

Therefore internal matrix/domain exchange and external top-boundary ownership remain distinguishable even though the same inflow reduction fraction is used.

## Kinematic-wave full-domain handling

For the main kinematic-wave domain, full-domain excess is resolved more locally.

When the macropore domain is full:

- top inflow is reduced first;
- if necessary, side inflows are also reduced;
- any excess not explained by top or side-inflow reduction and attributed to shrinkage-induced storage change is pushed into the top matrix compartment through `QOutMtxUnsDmCp`.

This last term is an **internal macropore-to-matrix transfer**, not an external surface loss.

## P2 — cross-domain redistribution

After every domain has been evaluated, source B1.11 may redistribute accumulated top excess to other macropore domains that still have storage capacity.

The algorithm:

1. calculates absolute and relative saturation deficit per domain;
2. sorts domains by ascending relative saturation deficit;
3. allocates a share of the remaining top excess using the domain proportion `PpDmCp/PpTot`;
4. caps that transfer by the receiving domain saturation deficit;
5. raises both its vertical and lateral top inflows proportionally;
6. decreases the global remaining top excess.

This is redistribution **within the macropore top-partition system**, not a new external water source.

## Remaining excess ownership

After cross-domain redistribution:

- if macropores reach the soil surface, remaining `FlwInTopExcesTot` is subtracted from `QMpLatSs`;
- tiny residuals are zeroed;
- with a covering layer, positive remaining excess is treated as an error.

The source comment explicitly states:

`Remaining inflow excess is substracted from lateral inflow into macropores for use in main SWAP`.

This means the legacy ownership chain is not:

`top input -> macropore -> generic overflow`.

It is instead:

`external top/surface receipt -> potential macropore partition -> capacity limitation -> optional cross-domain redistribution -> unused share returned to the owning surface/lateral route`.

## Consequence for R2

The A3/A4 synthetic `overflow` variable is useful only as a reduced stress-test receipt.

It must **not** become the source-authoritative production representation.

R2 process composition should expose at least:

- requested direct vertical macropore top amount;
- requested lateral/runoff macropore top amount;
- accepted vertical amount;
- accepted lateral amount;
- cross-domain redistributed amount;
- returned/unaccepted top amount;
- internal shrinkage-to-matrix amount.

The outer top-boundary owner can then reconcile these with the matrix/surface-water route without double counting.

## Open source question

`QMpLatSs` is imported into `MOD_macropore` through `MOD_swap_mp`, while the exact B1.11 macropore files contain its consumption/modification but not its upstream producer definition.

Before P1/P2 implementation is declared source-complete, A5 must trace the upstream `QMpLatSs` producer/consumer contract in the exact SWAP 4.3.1 composition or its generated/shared module authority.

This is a narrowed provenance task, not a blocker for local partition/excess falsification.

## Next local experiment

Build a reduced multi-domain partition harness that proves:

1. accepted vertical + lateral + returned share = requested top receipt;
2. cross-domain redistribution preserves the receipt exactly;
3. shrinkage excess is internal to matrix/macropore mass;
4. no generic external overflow term is required.
