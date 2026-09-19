# HYDRO-MEMORY capability gate

**Date:** 2026-09-19  
**Repository:** `abhedwig-cell/SWAP5`  
**Authority branch:** `integration/f-ci-canonical`  
**Purpose:** determine whether the preregistered HYDRO-MEMORY pilot can already be executed as a physically faithful SWAP5 groundwater experiment without inventing new model physics.

## Decision

**BLOCKED_BY_COMPOSITION_ADMISSION**

The current canonical repository contains most of the required physics separately, but the exact production composition needed by HYDRO-MEMORY is not yet admitted.

The blocker is not absence of Richards flow, groundwater exchange, atmospheric forcing, or basic Feddes root uptake. The blocker is that the admitted PPA-WU01 groundwater application-owner profile explicitly rejects `root_extraction_active`, while the live SWAP5-MODFLOW6 qualification envelope F-GC44 through F-GC49 was established with root extraction off and a very short near-equilibrium coupling window.

Therefore the scientific pilot must not yet be run and interpreted as evidence for groundwater-supported vegetation drought buffering or recovery.

## Gate matrix

| Gate | Requirement from preregistration | Current evidence | Verdict |
| --- | --- | --- | --- |
| G1 | dynamic groundwater storage | F-GC44 uses live MODFLOW6 6.8.0 with transient STO (`ss`, `sy`, `transient=True`) and the admitted groundwater service exchanges flux with live cell heads | **PASS structurally, restricted envelope** |
| G2 | groundwater head can change due to SWAP exchange | F-GC44/F-GC49 iterate on live MODFLOW heads and commit accepted SWAP exchange to MODFLOW; PPA-WU01 owns persistent committed SWAP state across window-scoped contexts | **PASS structurally** |
| G3 | vegetation/root demand can drive groundwater depletion | F-CI31 admits restricted Reference-ET to drought-only Feddes uptake, but PPA-WU01 `tile_config_valid` rejects `root_extraction_active` for the groundwater owner | **FAIL current composition** |
| G4 | precipitation/ET forcing can vary between windows | PPA-WU03 admits bounded precipitation + SWETR=1 reference ET + canopy + resolved irrigation forcing | **PASS separately** |
| G5 | groundwater can recharge during recovery | interface sign convention and prescribed-head corrector permit bidirectional exchange in principle; no long root-active drought/recovery composition has been qualified | **PARTIAL, must qualify** |
| G6 | root-zone, vadose-zone and groundwater storage diagnostics | SWAP trial/result diagnostics include storage change and bottom exchange; committed interface ledger is exact; live MODFLOW head is available | **PARTIAL** |
| G7 | explicit groundwater-storage diagnostic for (D_{gw}) | F-GC49D does not expose a groundwater-storage result; simple STO storage can be reconstructed from head/configuration or read from MODFLOW budget in a research harness | **MISSING RESEARCH DIAGNOSTIC** |
| G8 | combined water-balance gate | SWAP hard mass and interface action/reaction accounting are admitted; a combined multi-window SWAP + MODFLOW storage closure for the proposed experiment is not yet qualified | **PARTIAL** |
| G9 | hydraulic hysteresis excluded in primary pilot | PPA-WU01 restricted profile rejects `hysteresis_active` | **PASS** |
| G10 | advanced plant-stress memory excluded | advanced oxygen/salinity/frost/compensation/MICRO routes are outside the restricted admitted root-uptake profile | **PASS** |
| G11 | repeated coupling windows over drought and recovery | PPA-WU01 explicitly owns persistent FMR state across per-window F-GC49D context creation/retirement | **PASS structurally, duration not qualified** |
| G12 | groundwater tangent/corrector valid with root-active forcing | current real live groundwater qualification was root-extraction-off; no root-active coupled tangent qualification found | **FAIL qualification** |

## Controlling evidence

### PPA-WU01

`docs/audits/PPA_WU01_PRODUCTION_APPLICATION_BOOTSTRAP.md` establishes:

- persistent Fortran/FMR-owned committed state;
- a window-scoped F-GC49D groundwater context;
- persistent state across context creation and retirement;
- an admitted `bottom_mode=5` groundwater-owner profile.

However, `src/runtime/mod_fmr_production_application_bootstrap.f90` currently fails closed when any of the following are active, including:

`root_extraction_active`

This is the direct production-composition blocker for HYDRO-MEMORY.

### PPA-WU03

`src/adapter/mod_ppa_wu03_common_forcing_adapter.f90` already admits a bounded normal forcing route containing:

- precipitation;
- SWETR=1 reference ET;
- canopy state;
- already-resolved surface irrigation;
- dynamic-top materialization.

This is sufficient in principle for a synthetic drought/recovery forcing sequence without requiring legacy weather-file ingestion.

### F-CI31

`integration/f-ci/F-CI31_STATUS.json` admits:

`STATELESS_REFERENCE_ET_PTRA_TO_RESTRICTED_MACRO_FEDDES_DROUGHT_ONLY_PRECOMPUTED_QROT_ROOT_WATER_UPTAKE_EXECUTION_COMPOSITION`

This is close to the plant-water-use process required by the primary HYDRO-MEMORY pilot because the pilot deliberately excludes oxygen, salinity, frost, compensation and plant physiological recovery memory.

F-CI31 nevertheless retains explicit nonclaims around accepted-window integration and actual-transpiration mass-ledger admission. These must not be silently inferred into the groundwater composition.

### F-GC44 through F-GC49

The real live groundwater chain is genuine production physics and not merely an interface mock.

F-GC44 qualified:

- one real Reference-Richards/FMR SWAP column;
- one live MODFLOW6 6.8.0 model;
- transient MODFLOW storage;
- repeated coupled nonlinear iterations inside one window;
- exact accepted interface exchange;
- transaction-safe publication.

But its qualification envelope is explicitly:

- near equilibrium;
- `WINDOW_DAY = 1.0e-4`;
- `bottom_mode=5`;
- drainage off;
- **root extraction off**;
- macropore, snow and soil temperature off.

F-GC49D subsequently productionized the application context and ABI but explicitly made no new groundwater-physics-envelope claim.

Therefore F-GC49D does not widen F-GC44's root-active scientific evidence by itself.

## Important implementation observation

The groundwater forcing materializer in
`src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90`

copies the existing `base_forcing` and changes only `bottom_head`.

Therefore there is no obvious architectural reason why a precomputed root sink cannot coexist with a groundwater-head corrector. The current block is in the admitted profile and its evidence, not in the abstract forcing-materializer interface.

This is encouraging, but it is not scientific authority. Root-active coupled execution must still be explicitly qualified.

## Main numerical/scientific risk before admission

The current MODFLOW coupling uses an affine SWAP response

[
q_u(H)=q_{ref}+s(H-H_{ref}).
]

The live qualification established this response for the restricted root-inactive envelope.

For HYDRO-MEMORY, root uptake will alter the water profile and therefore the lower-boundary response. The primary prerequisite is not simply to remove the `root_extraction_active` guard. The root-active groundwater tangent must be independently checked.

For the restricted F-CI31 `SWKIMPL=0` style route, the root sink is precomputed from the accepted state and can remain fixed inside one coupling window. That makes compatibility plausible, but the following must be demonstrated:

1. the analytic accepted-trajectory groundwater tangent remains valid with nonzero root extraction;
2. finite-difference perturbations in prescribed groundwater head reproduce the analytic tangent within a preregistered tolerance;
3. root uptake remains identical across repeated correctors from the same accepted origin;
4. rejected correctors do not mutate root-uptake or hydrological state;
5. accepted actual transpiration is accounted once and only once;
6. the coupled water balance remains closed.

If these fail, HYDRO-MEMORY cannot use the current tangent/corrector route without a separate scientific/numerical workunit.

## Required bounded prerequisite

### HYDRO-MEMORY-CAP01
**Restricted root-active dynamic-groundwater research profile**

Purpose:

Admit one deliberately narrow research composition using existing physics only:

- Reference Richards;
- serialized FMR execution;
- `bottom_mode=5`;
- one SWAP column to one MODFLOW6 cell;
- transient MODFLOW storage;
- PPA-WU03 synthetic precipitation/reference-ET forcing;
- F-CI31 restricted drought-only Feddes root uptake;
- precomputed/frozen root sink within each accepted coupling window;
- no interception state;
- no SWREDU persistent evaporation state;
- no oxygen stress;
- no salinity stress;
- no compensation;
- no MICRO/Jong-van-Lier;
- no macropores;
- no snow;
- no soil temperature/frost;
- no hydraulic hysteresis;
- no irrigation;
- no lateral groundwater flow in the first research cell unless required for numerical anchoring.

### CAP01 must not

- change Richards physics;
- change Feddes equations;
- relax numerical tolerances to force admission;
- introduce a new solver;
- add plant physiological drought legacy;
- claim iMOD Coupler product integration;
- claim N:1 transferability;
- execute the full scientific ensemble before the prerequisite qualification passes.

## CAP01 qualification ladder

### Q1. Composition ownership

Permit `root_extraction_active` only for the exact restricted groundwater research profile.

All other previously rejected process families remain rejected.

### Q2. Root forcing immutability within a window

Capture one accepted origin.

For at least three different prescribed groundwater heads:

- execute correctors from the same checkpoint;
- verify identical root-extraction forcing;
- verify no accepted-state mutation before publication.

### Q3. Tangent check

At multiple hydrologic states including at least one stressed root zone:

- compute the admitted analytic (dq_u/dH);
- independently perturb groundwater head on both sides;
- recompute the full real SWAP corrector;
- compare central finite-difference and analytic responses.

The numerical tolerance must be preregistered from scale/error analysis, not chosen after viewing the result.

### Q4. Dynamic storage drawdown

Use a simple transient unconfined MODFLOW cell with known storage parameters.

Under zero precipitation and nonzero root demand, demonstrate:

- positive groundwater support to SWAP for at least part of the experiment;
- groundwater-head decline;
- SWAP/root-zone storage evolution;
- hard interface mass identity.

### Q5. Recovery/recharge

Switch to positive precipitation with lower atmospheric demand and demonstrate:

- downward recharge into groundwater for at least one valid state;
- groundwater storage/head recovery;
- no sign or double-counting error across the interface.

### Q6. Diagnostic sufficiency

Persist per accepted window:

- root-zone storage;
- below-root unsaturated-zone storage;
- total SWAP-column storage;
- actual transpiration;
- potential transpiration;
- root extraction by node;
- bottom exchange;
- groundwater head;
- groundwater storage or exact storage change;
- precipitation;
- surface evaporation;
- runoff/ponding if nonzero;
- SWAP mass residual;
- MODFLOW storage/budget residual;
- combined SWAP + groundwater residual.

### Q7. Multi-window preservation

Run a small pre-scientific sequence long enough to exercise repeated state advancement, for example:

- 2 days baseline;
- 3 days synthetic drought;
- 3 days recovery.

This is a qualification sequence, not the HYDRO-MEMORY scientific experiment.

Require:

- monotonically advancing accepted time/revision;
- a fresh window context each interval;
- no stale-context reuse;
- reproducible O0/O2 SWAP outputs;
- no qualitative change under a stricter timestep/tolerance replay.

## Research diagnostic decision

For the first one-cell experiment, groundwater storage may be diagnosed in either of two ways:

1. direct MODFLOW storage/budget output through the research harness; preferred;
2. an independently verified reconstruction from transient STO parameters and accepted head where the cell geometry makes that relation exact.

The method must be frozen before the Stage-0 scientific run.

## Consequence for the HYDRO-MEMORY preregistration

The previously defined scientific Stage 0 is **not authorized to start yet**.

The correct sequence is now:

[
	ext{CAP01 composition qualification}
ightarrow
	ext{diagnostic freeze}
ightarrow
	ext{soil-parameter freeze}
ightarrow
	ext{HYDRO-MEMORY Stage 0}
]

The existing scientific kill criteria remain unchanged.

In particular, CAP01 must not inspect or optimize for the later scientific quantity

[
R=f(D_{tot}).
]

CAP01 exists only to establish that the model composition and diagnostics are physically and numerically qualified.

## Overall conclusion

HYDRO-MEMORY is **not blocked by missing core hydrological physics**.

It is currently blocked by a narrow but real integration/evidence gap:

> **restricted root uptake and common atmospheric forcing are admitted separately from the dynamic groundwater application-owner profile, while the live coupled tangent/corrector evidence is root-inactive.**

This is a preferable blocker to discovering that the model lacks dynamic groundwater or root-zone physics entirely.

If CAP01 passes without physics or solver changes, the preregistered Stage-0 falsification experiment can proceed on a defensible model basis.

If CAP01 fails because the root-active affine groundwater response is not valid, the scientific pilot must remain blocked until that numerical/coupling problem is independently resolved.
