# Legacy-to-target migration map

**Status:** migration planning contract  
**Snapshot:** 2026-09-04  
**Legacy source:** all 63 Fortran files from the SWAP 4.3.1 source archive supplied for this audit

This map connects the SWAP 4.3.1 source tree to the [SWAP5 target component ownership map](component-map.md). It is **not** a proposal to rename legacy files one-to-one into new modules.

!!! warning "Baseline versus active refactoring"
    The inspected archive is the SWAP 4.3.1 legacy baseline. Active transactional and `headcalc` refactoring may be ahead of this archive. The map classifies responsibilities that must migrate; it does not claim that every current refactoring unit is already present in the `SWAP5` repository.

## Migration action vocabulary

| Action family | Meaning |
| --- | --- |
| `RETAIN_*` | Preserve qualified physical/numerical behaviour, but move it behind the target ownership/interface boundary. |
| `SPLIT*` / `DECOMPOSE*` | The legacy file mixes responsibilities that belong to several target components or data domains. |
| `ADAPTER*` | Compatibility, parsing, serialization or external exchange remains outside the computational kernel. |
| `REPLACE_INTERFACE` | Preserve the information exchanged, but replace shared/global-array interfaces with typed contracts. |
| `*_RETIRE*` | Retire a legacy control/global container only after extracted behaviour passes reference and mass-balance qualification. |

## Highest-risk cuts

### `swap.f90`: split orchestration from physics

The baseline `swap.f90` invokes configuration, input, meteorology, time control, crop development, irrigation, snow/frost, root extraction, bottom boundaries, drainage, soil water, temperature, solute, tillage, output and external exchange. It therefore spans **Public API, Runtime, Coupler, Kernel interval execution and Results/diagnostics**.

Target rule: no new SWAP5 monolith should reproduce this control graph. Runtime owns scheduling/policy; the kernel owns one deterministic trial over `[t0,t1]`; adapters own legacy I/O; coupler logic remains outside the kernel.

### `soilwater.f90`: separate physical state, solver interface and dispatch

The baseline routine initializes soil-water fields, saves/restores state through `SoilWaterStateVar`, dispatches between solvers, calculates groundwater level, storage and fluxes, and invokes hysteresis/macropore effects. These responsibilities must be divided among the **committed state domain, soil-water solver interface, solver implementation, kernel accounting and runtime policy**.

### `headcalc.f90`: extract the reference Richards solver without exporting its internals

The baseline Newton solve directly touches top and bottom boundaries, root extraction, drainage, irrigation, frost, snow, macropores, conductivity relations, convergence/retry flags and linear algebra. SWAP5 should preserve qualified Richards behaviour while converting these cross-links into explicit residual/source/boundary contracts. Newton vectors, Jacobians and factorisations belong to worker scratch.

### `variables.f90` and `arrays.f90`: destroy global ownership, not information

Every field must be classified as immutable parameters, committed physical state, forcing, numerical configuration, result/diagnostic or scratch. The information may survive; broad mutable global ownership must not.

## Complete inventory

The complete 63-file baseline is divided into four readable inventories:

- [Control, I/O and accounting](legacy-migration-control.md)
- [State, solver and hydraulic core](legacy-migration-hydraulic.md)
- [Surface, drainage, management and optional flow physics](legacy-migration-processes.md)
- [Crop, uptake, stress, solute and WOFOST-soil](legacy-migration-biophysics.md)

Together these inventories cover every `.f90` file in the supplied SWAP 4.3.1 source archive exactly once.

## Migration order

1. **Protect reference behaviour.** Keep SWAP 4.3.1/reference mode and current qualified audit gates runnable before moving boundaries.
2. **Cut I/O and entry-point ownership.** Put reading, output, paths/environment and external exchange behind typed adapters. Do not modernize file formats first.
3. **Classify global data before moving algorithms.** Decompose `variables.f90`, `arrays.f90`, plant/atmosphere interfaces and WOFOST-soil declarations by lifetime and ownership.
4. **Finish the transactional execution seam.** Extract trial/result/commit semantics and retry policy from `swap.f90`, `timecontrol.f90` and `soilwater.f90`.
5. **Extract the soil-water interface around the existing reference solver.** Keep `headcalc` mathematics working while boundaries, source terms and hydraulic queries become explicit contracts.
6. **Move physical modules one family at a time.** Surface, drainage, crop/ET, macropores, thermal/frost, solute and nutrient physics reuse the same typed state/forcing/result model.
7. **Introduce MultiSWAP storage/runtime layouts after ownership is explicit.** Then SoA, pools and templates can change layout without changing physical semantics.
8. **Retire legacy globals/control paths only after equivalence gates pass.** Removal is the final step, not the first.

## Per-file exit criteria

A legacy responsibility is not migrated merely because a new module exists. It can be retired only when all applicable conditions hold:

- target owner and data lifetime are explicit;
- no kernel code reads files, paths or hidden external exchange state;
- no rejected trial mutates committed physical state;
- physical options and numerical policy remain separate;
- process modules do not depend on soil-water solver internals;
- optional functionality allocates persistent state only when active;
- reference-mode regression covers the extracted behaviour;
- water balance closes for normal, retry and fallback paths;
- performance changes are qualified against reference mode;
- affected architecture invariants are recorded with qualification evidence.

## Traceability to active work

The transaction-controller work maps primarily onto `swap.f90`, `timecontrol.f90`, `soilwater.f90`, `variables.f90` and the future Runtime/Kernel transaction boundary.

The `headcalc` state-extraction work maps primarily onto `headcalc.f90`, `soilwater.f90`, hydraulic constitutive modules, `variables.f90`/`arrays.f90`, worker scratch and the future soil-water solver interface.

These workstreams should update the [implementation status map](implementation-status.md) only when evidence changes.

## Invariant review

D3c is particularly governed by invariants **1–9, 13, 16, 20–23, 25–30**. File-specific migrations may involve additional coupling or optional-physics invariants. Invariant 30 remains the governing rule: every material migration change identifies affected invariants and qualification evidence.
