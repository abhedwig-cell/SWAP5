# PPA-WU05-C Oxygen-stress source/state/owner authority

Date: 2026-09-19

Status: `PARTIAL_AUTHORITY_FROZEN / FULL_B1_11_CALLSITE_SOURCE_REQUIRED`

Canonical reconcile base: `integration/f-ci-canonical@1c6506d2bc223e4992e0f0b250568f43bb4a5829`.

## Purpose

PPA-WU05 selected oxygen stress as the next advanced-root review after macropore authority. This workunit does not migrate oxygen physics. It freezes the ownership and state boundary that follows from current repository authority and separates that from what still requires complete byte-exact B1.11 source materialization.

## Exact corrected-reference authority

The corrected SWAP 4.3.1 authority is B1.11.

For `SWAP/oxygenstress.f90`:

- canonical B0 SHA-256: `2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735`;
- corrected B1.11 SHA-256: `8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87`;
- the admitted B0-to-B1 correction is SWAP-007.

The SWAP-007 directory contains historical provenance metadata with an older, incorrect B0 hash ending in `b12f75`. That metadata is not used as current source identity. VQ-1c provenance repair is encoded in the canonical B0 manifest and in `apply_and_verify_canonical_b0.py`, both of which pin the B0 preimage ending in `e5735` and reproduce the corrected B1 hash above. PPA-WU05-C treats those two artifacts as the canonical provenance authority while retaining the README/qualification files as historical audit evidence only.

SWAP-007 changes only the representability guard around the Newton quotient `fi/fi_a`. Representable updates are unchanged. When the quotient is unrepresentable, the correction forces the existing large-`lnew` restart route instead of allowing floating-point overflow. This is a numerical robustness repair, not a new oxygen-stress model.

## Existing SWAP5 root owner is preserved

Current production root uptake is the F-CI31 restricted macro Feddes drought-only route in:

`src/process/mod_root_water_uptake_process.f90`.

Its physical mass result is one nodewise `root_extraction_sink`. Potential uptake and stress reductions are reconciliation diagnostics; they are not additional water transfers.

PPA-WU05-C freezes the same ownership rule for any future oxygen route:

**oxygen stress may modify the accepted root sink, but it does not become a second root-water mass owner.**

The final accepted water withdrawal must still appear exactly once through the existing root-extraction mass surface or an explicitly qualified successor to that same single-owner contract.

## Derived oxygen cache is not transactional state

Recovered S11/S9 Project-Library evidence is useful because it exposes hidden `SAVE` storage in a source-derived transformation of legacy `oxygenstress.f90`. It is corroborating ownership evidence, not a substitute for byte-exact B1.11 source materialization.

The extracted cache contains:

- `d_soil_term1`;
- `d_soil_term2`;
- `gfp100`;
- `capac_term`;
- `nmin1`;
- `mplus1`.

The S11 extraction shows these values are built in `calc_ini_pars` from soil/grid/hydraulic configuration and reused by `OxygenStress`. The later S9 ownership correction explicitly removes that cache from transactional snapshots and moves it into immutable-after-construction shared data.

That evidence is not promoted to a B1.11 physics oracle. It is used only for ownership classification.

The target rule is therefore:

`OxygenStressCache = shared derived data, not physical continuation state`.

Consequences:

- it is not checkpointed on every trial;
- it is not rolled back;
- it is not persisted in restart payloads;
- it may be shared only by columns with an identical construction key;
- that key must contain every source input that affects the derived values;
- historical evidence specifically notes that the initial hysteresis wetting/drying branch must be included when `watcon()` depends on it.

## What is still unresolved

The current Git tree pins the exact B1.11 oxygenstress identity but does not contain the complete byte-exact B1.11 `oxygenstress.f90` plus `rootextraction.f90` call graph as source text.

The historical S11 patch modifies `oxygenstress.f90`, but not the unchanged root-extraction callsite. Therefore PPA-WU05-C does not infer the complete integration order from partial diffs.

Held for a later source-materialization slice:

- exact caller/callee sequence around `OxygenStress(node,rwu_factor)`;
- complete plant, soil, atmospheric and hydraulic input list;
- exact composition order with drought and any other active root stress factors;
- whether caller-side continuation/provenance exists outside oxygenstress itself;
- exact source oracle for ordinary and pathological oxygen cases.

No production DTO is frozen from an incomplete callsite trace.

## Transaction contract

A future oxygen-active root trial must follow:

```text
committed external hydraulic/crop/forcing state
        |
        +--> oxygen stress evaluation
        |      shared immutable derived cache
        |      worker-local disposable numerical scratch
        |
        +--> root sink candidate
        |
        +--> enclosing hydraulic transaction
               |
               +--> reject: publish nothing, retain committed state
               |
               +--> accept: publish exactly one root_extraction_sink
```

SWAP-007 remains mandatory numerical authority. A migration may not replace the corrected representability guard with a new tolerance, fallback or physics shortcut.

Oxygen evaluation does not own Richards timestep or retry policy.

## Restart

PPA-WU05-C finds no source-bound evidence that the six derived cache arrays are physical continuation state. They are therefore excluded from restart authority.

No claim is made that the complete oxygen route is restart-stateless. That final statement requires the complete B1.11 oxygen/root callsite trace.

## Groundwater coupling consequence

F-GC30 deliberately fails closed when a state-dependent root owner lacks derivative coverage.

An oxygen-active root route therefore cannot automatically inherit current groundwater tangent authority. Before an oxygen-active coupling claim is admitted, SWAP5 must qualify how the accepted root sink responds to groundwater/head perturbations under oxygen stress.

Centered finite difference is not an admitted production fallback merely because analytic coverage is incomplete.

## Required next slice

### PPA-WU05-C1

Byte-exact B1.11 `oxygenstress.f90` and `rootextraction.f90` materialization plus complete call-graph/input/state census.

Only after C1 may implementation begin.

Later bounded slices are:

- C2: typed oxygen evaluator and exact source oracle;
- C3: composition with the existing root sink owner and production transaction/mass qualification;
- C4: derivative coverage plus parallel execution.

## Nonclaims

PPA-WU05-C does not admit:

- oxygen-stress production physics;
- salinity or frost stress;
- compensated uptake;
- MICRO/Jong-van-Lier;
- macropore uptake;
- SWKIMPL=1 dynamic root-sink reevaluation;
- a new oxygen model;
- a new mass owner;
- an oxygen-active MODFLOW tangent route.

## Verdict

`PARTIAL_AUTHORITY_FROZEN_FULL_B1_11_CALLSITE_SOURCE_REQUIRED`

The main ownership ambiguity is removed: oxygen is not a separate water-mass owner, and the recovered hidden oxygen cache is derived shared data rather than rollback/restart state.

Production implementation remains held until C1 recovers the complete B1.11 oxygen/root integration source.
