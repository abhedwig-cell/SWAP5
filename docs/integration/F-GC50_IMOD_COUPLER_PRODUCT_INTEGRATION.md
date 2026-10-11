# F-GC50 — iMOD Coupler product integration

## Purpose

F-GC50 is the first bounded workunit after the canonically closed F-GC49 production application orchestration.

Its intended capability is narrow: place the already admitted SWAP5-MODFLOW6 production application path inside the **actual iMOD Coupler product driver/configuration lifecycle** without moving state, physics, transaction, linear-response, aggregation or XMI ownership to a new layer.

F-GC50 is not an F-GC49 Stage E. F-GC49 remains closed.

## Reconciled external product authority

The current upstream product inspected by this workunit is:

- repository: `Deltares/imod_coupler`
- branch: `main`
- pinned inspected commit: `8907fb13f8301ba1e0f32dd90a64ea475d4896d6`

At that commit, the product entry route is:

`run_coupler -> BaseConfig -> get_driver -> Driver.execute`

`Driver.execute` owns the outer product lifecycle: initialize, repeated update while current time is below end time, then finalize.

The current `DriverType` and `get_driver` surface recognizes only MetaMod, RibaMod and RibaMetaMod. There is no entry-point/plugin registry through which SWAP5 can be added without changing upstream product code.

The existing MetaMod driver also owns its concrete coupled timestep loop. It prepares the MODFLOW timestep, opens a prepared solve, performs coupled iterations, then finalizes MODFLOW and MetaSWAP timesteps.

## SWAP5 authority that must be reused

F-GC50 must consume, not replace, the already admitted SWAP5 ownership chain:

- F-GC33: linear groundwater response evaluation and re-anchoring;
- F-GC34: typed MODFLOW6 package binding/publication;
- `Modflow6PreparedSolveSession`: live XMI package pointers, `prepare_solve`, iterative `solve`, `finalize_solve`, timestep readiness and one-shot `finalize_time_step`;
- F-GC40: N:1 cell aggregation;
- F-GC41/F-GC49C: whole-window convergence and publication ordering;
- F-GC49D: production FMR cross-language application context and opaque context handle.

The product driver may coordinate the lifecycle but may not become owner of SWAP committed/candidate state, F-GC40 aggregation, F-GC33 mathematics or mass ledgers.

## Reconciled blocker 1 — no upstream product extension route

At the pinned iMOD Coupler commit, adding a fourth driver requires changing upstream product source at least in the driver/configuration registry. No plugin or external entry-point mechanism exists.

The GitHub connection available to this workunit has read/pull permission but no push permission on `Deltares/imod_coupler`. Therefore this repository cannot truthfully claim that the real iMOD Coupler product route has been modified or admitted.

A local imitation of `get_driver`, a monkeypatch, or a SWAP5-only duplicate product loop is explicitly forbidden as evidence of product integration.

## Resolved internal prerequisite B2 — admitted production bootstrap now exists

F-GC49D still correctly exposes an **existing registered Fortran application context** through an opaque handle. The production Python adapter continues to require the SWAP5 shared-library path and a positive existing context handle. No Python-owned SWAP state and no production `create_context_from_config` C ABI have been introduced.

The missing owner is now supplied by canonically admitted **PPA-WU01**. Its production module `mod_fmr_production_application_bootstrap.f90` owns the persistent Fortran/FMR application state and, for the restricted groundwater profile, the participant registry, participant handles, interface mass ledgers and the lifecycle of a per-window F-GC49D application context. It registers that context through the existing F-GC49D C-API registry and exposes only the resulting opaque handle to orchestration clients.

Therefore historical blocker **FGC50-B2 is resolved** for the restricted PPA-WU01 groundwater profile. This does not broaden the admitted physics envelope. It also does not mean that iMOD Coupler configuration mapping already exists: that mapping is ordinary F-GC50 implementation work to perform after the upstream product can actually register a SWAP5 driver.

## Product integration target after blockers clear

The intended product composition is:

1. iMOD Coupler parses a product configuration and selects a SWAP5-MODFLOW6 driver through its real driver registry;
2. the driver initializes the MODFLOW6 kernel using the upstream product wrapper;
3. an admitted SWAP5 bootstrap creates/owns the FMR application state and registers one F-GC49D context per coupling window;
4. the driver calls MODFLOW `prepare_time_step` once for the window;
5. the admitted F-GC49C service consumes the F-GC49D runtime and `Modflow6PreparedSolveSession`;
6. predictor/corrector iteration remains product-level orchestration, while the admitted SWAP5 service controls the bounded window semantics already qualified by F-GC49;
7. publication order remains MODFLOW timestep, SWAP commits, ledger commits;
8. accepted product time advances only after successful bounded-window publication.

## Explicit non-goals

F-GC50 does not authorize:

- new SWAP physics;
- new groundwater physics;
- a second transaction lifecycle;
- a second MODFLOW prepared-solve abstraction;
- Python ownership of FMR state or ledgers;
- promotion of F-GC44 through F-GC47 qualification bridges;
- a new legacy-file parser;
- physics-envelope expansion;
- heterogeneous N:1 transferability claims;
- SCALE experiments.

## Current disposition

F-GC50 is **internally ready for its restricted admitted profile but externally blocked before product implementation**.

The remaining blocker is concrete and independently inspectable:

1. upstream iMOD Coupler must provide or accept a real SWAP5 driver registration/integration route.

The internal bootstrap prerequisite is no longer blocking: PPA-WU01 is canonically admitted for the restricted groundwater production profile and can materialize the required F-GC49D context from a Fortran/FMR-owned application state.

Actual product integration is still **not admitted** because the inspected upstream product has no external driver plugin route and the connected GitHub authority remains read/pull only. A SWAP5-local imitation of the product registry or coupled timestep loop remains ineligible as evidence.
