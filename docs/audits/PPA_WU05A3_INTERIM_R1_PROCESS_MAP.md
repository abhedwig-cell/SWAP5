# PPA-WU05-A3 interim R1 process map

Date: 2026-09-30

Status: `INTERIM_RESEARCH_AUTHORITY / READY_FOR_COUPLED_R2_EXPERIMENTS / NOT_PRODUCTION_ADMISSION`

## Executive conclusion

The first local A3 campaign has now exercised the planned E0-E9 research surface sufficiently to define an interim corrected-reference (R1) process map.

The main conclusion is not that B1.11 should be copied into SWAP5.

Instead, the exact source supports a smaller set of explicit physical/history contracts, plus two areas where historical post-acceptance bookkeeping should be corrected or clarified before migration.

## Physical continuation state retained

A1/A2 seven-field state remains supported:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

A3 adds direct executable support for two nontrivial history components:

### Sorptivity memory

E3 showed that identical current water stores can produce more than a fourfold difference in the next absorption rate solely because event history differs.

Therefore the sorptivity triplet is genuine process memory.

### Crack hysteresis

E4 showed that identical current moisture can yield zero or positive dynamic crack volume solely because prior/local-neighbour crack history differs.

Therefore `VlMpDyCp` is genuine hysteretic process state.

## Process ownership map

### Surface input

Macropore top inflow is a partition of the external top-boundary receipt.

It is not an additional rainfall/irrigation source.

### Matrix/macropore exchange

Sorptivity/Darcy exchange is internal to the combined matrix/macropore water system.

E2/E3 show stored macropore water can subsequently move into the matrix.

Internal exchange must cancel in whole-column mass.

### Macropore storage

Finite accepted storage is physical state.

Storage is candidate-mutated during trial execution and promoted only on accept.

### Dynamic crack geometry

Current geometry can be recomputed, but `VlMpDyCp` history cannot be discarded because it changes the crack-opening/closing branch.

### Rapid drainage

E5 supports one external rapid-drain owner.

At fixed geometry the isolated source relation activates continuously above the drain/base elevation and is capped by drainable storage.

### Excess input

E9 supports an explicit excess/overflow ownership requirement once finite storage and all permitted sinks are exhausted.

The exact B1.11 redistribution algorithm remains a later detailed comparison item.

## Corrected interface-index rule

A1 proved `icgwl` is undefined in the B1.11 standard `MACROSTATE` path.

E6 initially supported direct reuse of `ICpTpWaSrDm`.

E7 refined that conclusion.

Interim R1 meaning:

`icgwl` = first compartment at or above the stored-water body that is not fully saturated.

Research implementation rule:

1. start from `ICpTpWaSrDm(id)`;
2. if that compartment is fully saturated and it is below `ICTopMP`, move one compartment upward;
3. otherwise retain the index.

This reproduces the independent kinematic source construction across 10,001 dry-to-full storage states with zero index mismatches.

## Accepted vertical-flux reconstruction

A separate historical issue was found after correcting the index.

For the standard route, B1.11 reconstructs accepted `QTopMpDmCp`:

- top-down using actual water-storage change in the unsaturated region;
- bottom-up using macropore-volume change in the saturated region.

When the interface is stationary, this is locally conservative.

When a compartment changes saturation class across the step, equal/opposite local residuals can appear while whole-domain mass remains exact.

R1-MSTATE02 showed that a universal post-acceptance reconstruction:

`Q_bottom = Q_top - Q_exchange - DeltaW/dt - Q_external_compartment`

is locally and globally conservative and agrees with the historical result for stationary interfaces.

Interim R1 policy:

- retain source-bound rate/state physics;
- reconstruct accepted diagnostic vertical flux from one local conservation identity after accepted storage is known;
- do not use the moving saturation interface to split diagnostic-flux reconstruction.

## PEARL/ANIMO relevance

Exact source review shows compartment-resolved `QTop` is exported to PEARL/ANIMO only for `swmbf=2`, where the kinematic-wave route already computes it directly with explicit compartment mass checks.

Therefore the standard-route reconstruction issue is not currently a demonstrated PEARL/ANIMO transport defect.

It remains relevant for standard-route diagnostics/CSV output and for any future SWAP5 generic compartment-flux interface.

## Transaction semantics

E8 supports the A2 model under combined source-shaped state mutation:

- all seven fields may mutate in a trial;
- reject discards the complete candidate;
- retry from identical accepted state reproduces the clean candidate exactly.

No macropore history may live in hidden module-global state in R2.

## Extreme-load ownership

E9 supports the desired bounded bookkeeping under extreme forcing:

- storage bounded;
- internal exchange single-owned;
- rapid drainage single-owned;
- excess explicit;
- no mass created by clipping/capping.

## Interim R1 equations versus architecture

The following should be distinguished in R2:

### Preserve initially

- B1.11 physical parameter meanings;
- surface partition semantics;
- sorptivity-event physics;
- dynamic crack hysteresis;
- matrix/macropore exchange sign convention;
- rapid drainage physical sign/ownership;
- accepted finite storage.

### Correct/reformulate

- undefined `icgwl` source behaviour;
- standard-route post-acceptance `QTop` split reconstruction;
- implicit module-global continuation ownership;
- legacy trial rollback incompleteness.

### Recompute as derived

- water level;
- wet-wall fraction;
- top stored-water compartment;
- aggregate macropore volumes;
- other geometry views already classified as derived in A1.

## What A3 has not yet established

A3 has not yet qualified:

- full coupled Richards/macropore execution;
- Darcy + sorptivity combined exchange across realistic profiles;
- detailed multiple-domain interaction;
- exact B1.11 excess redistribution;
- moving domain-bottom edge cases;
- performance;
- field calibration or identifiability;
- broad real-case equivalence.

## Next research phase

The next logical block is a coupled R2 single-column prototype.

Recommended order:

1. prescribed Richards-state adapter;
2. R1 macropore candidate-rate calculation;
3. atomic seven-field candidate state;
4. locally conservative accepted flux reconstruction;
5. one-step matrix/macropore water exchange;
6. reject/retry proof;
7. then introduce a real Richards solve and timestep interaction.

The first coupled tests should reuse E2, E3, E4 and E7 as regression oracles.

## Interim decision

`A3_LOCAL_PHYSICAL_DECOMPOSITION_SUFFICIENT_FOR_COUPLED_R2_RESEARCH`

This is a research progression decision, not production qualification or canonical admission.
