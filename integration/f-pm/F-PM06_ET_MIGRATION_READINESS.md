# F-PM06 Evapotranspiration Process Boundary, State & Migration Readiness

## Decision scope

F-PM06 is a readiness-only workunit. It does not move, merge, or modify production ET physics.

Decision target:

`QUALIFIED_ET_MIGRATION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE`

The first structural candidate must be separate from this workunit.

## Baseline reconciliation

The reserved branch `work/f-pm06-et-migration-readiness` was confirmed to contain no F-PM06-specific commit and to remain at stale reservation commit `fafeebdece209abcc320b24a3c8c2757800b2e0e`.

The live canonical ref was rechecked as:

- ref: `integration/f-ci-canonical`
- commit: `df435824de175e3f868b680aab2cd0a395aa19ff`
- tree: `f16791352d84853c8aa758e40662debebd6249b9`
- commit message: `status(F-CI23): close after canonical validation`

The old reservation commit is an ancestor of the canonical commit. The reservation branch was therefore advanced by non-forced fast-forward only. No production commit from an ET/crop side branch was merged.

F-CI23 remains the current canonical source authority. Its persisted status still carries a final governance-head replay/requalification note, so F-PM06 does not broaden that governance claim.

## Frozen source and qualified-owner authorities

### Legacy SWAP 4.3.1 B1.10

The source-bound ET evidence already persisted by F-WOF18 identifies:

- uploaded archive `SWAP_4.3.1(6).zip`, SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested source archive `SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`, SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- `MOD_meteo.f90`, SHA-256 `5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822`
- `swap.f90`, SHA-256 `39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`

The canonical controlled port in `src/legacy/b1_10_fci11_port/` is used for live call-order reconciliation. The exact B1.10 archive above remains the equation-level source authority.

### Root-water-uptake owner

F-VQ22 independently qualified F-PM05 for the restricted profile:

`QUALIFIED_INDEPENDENT_FPM05_MACRO_FEDDES_DROUGHT_ONLY_ROOT_WATER_UPTAKE_SCIENTIFIC_ADMISSION`

The canonical source `src/process/mod_root_water_uptake_process.f90` has blob `e6134587cf3c0164bbe09f2f4c87aef6886aaeb3`, matching the qualified F-VQ22 process blob.

Its contract is intentionally downstream of ET:

- input demand: `potential_transpiration`
- crop/root inputs: `rooted_nodes`, normalized cumulative root fraction
- hydraulic input: clean committed pressure-head process view
- physical output: nonnegative nodewise `root_extraction_sink` and total actual uptake
- persistent root-uptake process state: none in the qualified restricted profile

Therefore F-PM06 does **not** admit Feddes stress, qrot allocation, compensated uptake, oxygen/salinity/frost stress, Jong-van-Lier/MICRO uptake, or macropore uptake into the ET owner.

### Crop/canopy owner

Current canonical contains the transactional WOFOST crop owner and the F-WOF38/F-WOF42 qualification records. Crop biology and continuation state stay crop-owned.

Relevant classification carried forward from the source-bound WOF work is:

- committed crop state: crop emergence, development stage and physically required WOFOST continuation/biomass state;
- optional crop/root history only when the selected crop/root option physically needs it;
- reconstructible views such as LAI, vegetation cover, crop factor and root geometry are not ET commit authority;
- ET consumes a read-only canopy snapshot and never advances crop physics.

### Qualified restricted ET evidence

F-WOF18 qualified the source `src/process/mod_reference_et_transpiration_process.f90`, blob `497b42f2450a003a070dbc4020573866d1ef93b0`, for:

`SWETR=1, SWMETDETAIL=0, SWDIVIDE=0, SWINTER=0`

It is a stateless current-result producer for potential transpiration only. This production source is **not present on the current canonical ref** and is therefore evidence/provider authority, not merge authority. A later F-PM06 implementation unit must re-admit the required source on current lineage under repository governance rather than blindly merge the historical branch.

## Source-bound ET decomposition

### 1. Atmospheric potential-demand formation

Legacy `ETpot` (`MOD_meteo.f90:1399-1489`) forms atmospheric demands from meteorology plus a read-only canopy view.

For `SWETR=1, SWMETDETAIL=0`:

- bare-soil demand: `es0 = etr * (1-vcover)`, optionally multiplied by `cfbs`;
- ponded-water demand: `ep0 = etr * (1-vcover) * cfevappond`;
- dry-canopy transpiration demand: `et0 = etr * vcover * cf` when crop emerged;
- wet-canopy atmospheric demand basis: `ew0 = etr * vcover * cf` when crop emerged;
- rate outputs: `peva=max(es0*0.1,0)`, `epond=max(ep0*0.1,0)`, `ptra_dry=max(et0*0.1,0)` and CO2 correction;
- wet-canopy partition produces `ptra_wet` and `eintc`.

For `SWETR=0` or detailed meteorology, `penmon(...)` supplies `es0/et0/ew0/ep0`. F-PM06 maps this branch but does not scientifically qualify Penman-Monteith equations as a new SWAP5 provider.

**Owner boundary:** atmospheric ET-demand provider. It is a pure/current-result calculation and has no authority over crop state, root uptake, soil-water state, pond storage, or mass-ledger commit.

### 2. Interception evaporation and wet-canopy effects

Legacy has two fundamentally different families.

For `SWINTER=1` or `2`, `interception_daily()` (`MOD_meteo.f90:2055-2092`) computes a source-window aggregate `aintc` using Von Hoyningen-Hune/Braden or Gash. `ProcessMeteoDT` apportions that aggregate to the active precipitation interval as `aintcdt`, deducts it from gross rain/irrigation, and uses `wfrac` to blend `ptra_wet` and `ptra_dry`.

For `SWINTER=3`, Rutter (`MOD_meteo.f90:2202-2304`) is a dynamic canopy reservoir:

- committed physical storage: `sicact`;
- current derived capacity: `siccap` from canopy state;
- trial inflow/outflow: `crsflx_in`, `crsflx_out`;
- interception input from precipitation: `aintcdt = crsflx_in`;
- wet fraction: `wfrac`;
- process event: `dt_interc_event`, the time to full/empty reservoir.

Legacy integration updates `sicact` using `(crsflx_in-crsflx_out)*dt`. In SWAP5 this update must be a trial candidate and must occur only at authoritative transaction commit.

A capacity decrease creates `siccaploss` in crop/interception code. Legacy `integral(4)` adds this loss to interception-loss accumulators and removes it from canopy-reservoir storage. F-PM06 freezes this as reference behavior. It must not be silently reinterpreted as throughfall or surface-water input. Any physical change requires a separate physics workunit and mass-conserving qualification.

**Owner boundary:** hydrological interception process. Canopy geometry/capacity drivers are read-only crop views. The liquid canopy reservoir is not crop-biomass state.

### 3. Bare-soil evaporation reduction

Legacy `reduceva` (`MOD_meteo.f90:1497-1563`) converts potential soil evaporation `peva` into empirical demand `empreva`.

- `SWEVAP=0`: demand forced to zero;
- ponded surface: `empreva=epond`, and empirical dry-surface memory is reset;
- `SWREDU=0`: no empirical state, top boundary uses `peva` directly;
- `SWREDU=1`, Black: persistent `ldwet`;
- `SWREDU=2`, Boesten-Stroosnijder: persistent `spev` and `saev`.

Legacy restart explicitly persists `LDWET` for `SWREDU=1`, or `SPEV/SAEV` for `SWREDU=2` (`swapoutput.f90:423-432`). These are real continuation state and cannot be reconstructed from the instantaneous hydraulic profile alone.

A migration hazard is source-bound in the legacy driver: `Meteo(3)` and therefore `reduceva()` execute before the SoilWater nonconvergence retry loop. `reduceva()` mutates `ldwet/spev/saev` immediately. If SoilWater later reduces `dt`, legacy control flow does not visibly restore those ET states and replay `reduceva()` from the same checkpoint before retry. SWAP5 must **not** copy this mutation pattern. The physics equations may be preserved, but trial-state advancement must be transactional.

**Owner boundary:** soil-evaporation-reduction process. It may read accepted/current surface wetting and a clean surface-water view, but it may not read solver internals.

### 4. Ponded-water evaporation and actual bare-soil evaporation

Legacy `BoundTop` (`boundtop.f90:83-116`) proves that atmospheric ET only supplies demand. Actual evaporation is a surface/soil-water boundary result:

- if previous accepted ponding is positive: `reva=0`, `epd=epond`;
- otherwise: `epd=0` and `reva` is limited by hydraulic `Emax`, using `peva` for `SWREDU=0` or `empreva` otherwise.

`Emax` depends on top-node hydraulic state and conductivity. This calculation belongs to the soil-water/top-boundary owner. ET code must never inspect HeadCalc arrays, Newton vectors, Jacobian storage or constitutive solver globals.

**Required interface:** ET supplies evaporation demands. The hydraulic/top-boundary process consumes those demands through a clean top-boundary hydraulic view and returns accepted/trial `actual_soil_evaporation` and `actual_pond_evaporation` fluxes.

### 5. Crop transpiration demand versus actual root uptake

`ptra` is atmospheric/canopy demand. Actual root-water withdrawal is `qrot`/node sinks from the root-uptake process. The two are separate process outputs and separate mass semantics.

F-PM06 therefore forbids an ET implementation from calculating Feddes stress or allocating root sinks. ET may publish `potential_transpiration`; root uptake consumes it and produces actual sinks from its own qualified hydraulic view.

## Dependency map

```text
forcing span/event
  |-- reference ET or detailed meteorology
  |-- precipitation / irrigation / snow partition
  v
atmospheric ET-demand provider  <--- read-only crop/canopy view
  |-- potential soil evaporation
  |-- potential pond evaporation
  |-- dry/wet potential transpiration
  |-- wet-canopy evaporation capacity
  |
  +--> interception process <--- crop canopy geometry
  |      |-- SWINTER 1/2: source-window aggregate, no storage
  |      |-- SWINTER 3: optional canopy-water state + process-event bound
  |      +--> net rain / net sprinkling + canopy evaporation ledger terms
  |
  +--> soil-evaporation-reduction process
  |      |-- SWREDU 0: stateless
  |      |-- SWREDU 1: optional LDWET state
  |      +-- SWREDU 2: optional SPEV/SAEV state
  |             ^
  |             +--- clean surface-water/wetting view
  |
  +--> root-water-uptake process
  |      ^  clean committed hydraulic pressure-head view
  |      +--- crop root geometry
  |      +--> actual nodewise root sink
  |
  +--> soil-water/top-boundary process
         ^  clean top-boundary hydraulic + pond view
         +--> actual soil evaporation / actual pond evaporation
```

No arrow permits access to HeadCalc/Newton/Jacobian internals.

## Process interface contract

The exact type names are deferred to the structural-candidate workunit. The semantic interfaces are frozen here.

### `AtmosphericDemandProvider`

Inputs:

- generic time span `[t0,t1]` plus forcing provenance/span identity;
- ET physical configuration;
- meteorological forcing valid on that span;
- read-only canopy snapshot from the crop owner.

Outputs, as current trial results:

- potential soil evaporation demand;
- potential ponded-water evaporation demand;
- dry and wet potential transpiration demand;
- wet-canopy evaporation capacity/result needed by interception;
- diagnostics and source-span identity.

Persistent state: none.

### `InterceptionProcess`

Inputs:

- forcing/event precipitation and applicable sprinkling irrigation;
- current canopy snapshot;
- atmospheric wet-canopy demand;
- optional committed interception state only for a stateful method.

Outputs:

- net precipitation and net sprinkling fluxes;
- canopy evaporation mass flux;
- trial next interception storage when stateful;
- source-window aggregate for daily methods when applicable;
- next physical event boundary when stateful;
- diagnostics.

Persistent state:

- none for `SWINTER=0,1,2` under B1.10 semantics;
- `sicact` only for `SWINTER=3`.

### `SoilEvaporationReductionProcess`

Inputs:

- potential bare-soil evaporation;
- net rain/net sprinkling wetting over `[t0,t1]`;
- clean surface-water view containing ponded-water presence/depth semantics;
- optional committed reduction state.

Outputs:

- trial empirical soil-evaporation demand;
- trial next reduction state;
- diagnostics.

Persistent state:

- none for `SWREDU=0`;
- `ldwet` for `SWREDU=1`;
- `spev` and `saev` for `SWREDU=2`.

### `RootWaterUptakeProcess`

Existing qualified owner. ET provides demand only. No duplicated root physics.

### `SurfaceHydraulicEvaporationBoundary`

Existing/future soil-water boundary owner. It consumes ET demands and a clean hydraulic view, calculates hydraulic limitation, and publishes actual soil/pond evaporation. ET does not own `Emax` or solver state.

## Mass-contribution contract

Potential quantities are **not** authoritative mass removals:

- `peva`, `epond`, `ptra_dry`, `ptra_wet`, `ptra` are demands/results only.

Authoritative accepted water-mass contributions are:

- actual root-water sink from root uptake;
- actual bare-soil evaporation from the top-boundary/hydraulic process;
- actual ponded-water evaporation from the surface/top-boundary process;
- canopy evaporation for daily interception methods;
- for Rutter: canopy storage inflow, canopy evaporation outflow and accepted canopy-storage delta, with net precipitation derived consistently;
- legacy `siccaploss` as a separate accepted canopy-storage loss term with explicit reference semantics.

Rules:

1. Every physical flux is entered exactly once in the authoritative accepted-interval mass ledger.
2. `crsflx_in` in Rutter is a transfer from precipitation to canopy storage, not canopy evaporation. Do not count it as both interception evaporation and storage inflow.
3. Net rain/irrigation cannot be combined with gross precipitation without the corresponding interception transfer/loss identity.
4. Potential ET integrations (`iptra`, `ipeva`) are diagnostics/reporting, not mass sinks.
5. Cumulative legacy `i*`/`c*` counters move to result aggregation/diagnostics, not process continuation state.
6. No tolerance or fallback may relax mass conservation.

For a stateful Rutter interval, the accepted canopy identity is conceptually:

`S_int(t1) - S_int(t0) = intercepted_input - canopy_evaporation - reference_capacity_loss`

with the exact legacy sign/route for capacity loss preserved until a separately qualified physics change says otherwise.

## Generic-time contract

Time units in legacy rate names such as `cm/d` or `mm/d` do not make one day a kernel timestep.

1. The kernel evaluates a generic `[t0,t1]` span.
2. A daily ETref/weather record is a forcing span with explicit validity, not an implicit midnight-to-midnight kernel loop.
3. `SWINTER=1/2` source-bound daily interception remains an aggregate over its explicit forcing/event window. A structural candidate may not silently apply the nonlinear daily formula independently to arbitrary subwindows.
4. Detailed meteorology uses explicit forcing segments (`dt_meteo` in legacy). `meteo_rec`, `i_metdetail`, `fl_update_meteo` and file cursors become adapter/runtime forcing-cursor concerns, not kernel state.
5. Rutter `dt_interc_event` becomes a physical process event bound returned to the runtime. It does not mutate a global solver `dt`.
6. Crop advancement keeps its own accepted crop-event semantics. ET reads the crop snapshot valid for the trial span and never advances crop calendar state.
7. Any legacy DLL restriction to one day is adapter behavior only and is explicitly not inherited by the kernel.

## Transaction contract

All ET-related processes use `checkpoint -> trial/retry -> commit or rollback`.

- Stateless potential-demand evaluation may be recomputed freely.
- `ldwet`, `spev`, `saev` and `sicact` are read from the committed checkpoint and written only into trial-local candidate state.
- A rejected hydraulic trial leaves all committed ET/interception state unchanged.
- A retry with smaller `dt` is recomputed from the same committed state. Trial trajectories may be reused only as numerical hints, not as physical committed history.
- `siccaploss` generated by an accepted crop/canopy transition must be transactionally composed with the interception state so canopy water is neither lost twice nor retained after capacity has changed.
- Actual fluxes enter the authoritative mass ledger only on the same accepted transaction that advances the corresponding physical state.
- Reporting accumulators update after commit or derive from committed ledger receipts. They are never commit authority.

Required structural-candidate tests include A/B/A replay, rejected-trial immutability, failed-then-accepted retry with changed `dt`, and exactly-once mass receipts.

## Optionality and MultiSWAP storage

State allocation follows active physics only:

- `SWINTER=0,1,2`: zero persistent canopy-water state for interception;
- `SWINTER=3`: one canopy-water storage scalar plus only metadata required by the process contract;
- `SWREDU=0`: zero soil-evaporation reduction state;
- `SWREDU=1`: `ldwet` only;
- `SWREDU=2`: `spev` and `saev` only;
- no ET copy of crop owner state;
- no ET copy of hydraulic profile state;
- no per-column meteorological file arrays or tables in the kernel.

Immutable ET/crop/interception parameter sets are shared by IDs/references. Trial temporaries and PM/Rutter algebraic intermediates belong to worker scratch. Execution classes may group columns by ET/interception/reduction topology without changing physics.

## Legacy variable classification boundary

The machine-readable companion `F-PM06_LEGACY_VARIABLE_CLASSIFICATION.json` classifies every named module-scope or cross-process variable in the ET migration inventory. Pure local algebraic temporaries inside `penmon`, `astro`, `Gash`, `VonHHBraden`, `Rutter`, `reduceva` and `BoundTop` are worker scratch by definition and do not become per-column persistent state.

The classification uses these target categories:

- `IMMUTABLE_PARAMETER`
- `FORCING`
- `COMMITTED_PERSISTENT_STATE`
- `ACCEPTED_PROCESS_AGGREGATE`
- `OUTPUT_RESULT`
- `WORKER_SCRATCH`
- `REMOVABLE_LEGACY_BOOKKEEPING`

Where a variable is physically owned outside ET, the classification also records that owner.

## Migration slices

### Slice E0: contracts and oracles only

Freeze DTOs/views, legacy equation oracles, retry tests and mass identities. No production physics.

### Slice E1: restricted stateless reference-ET demand provider

Recommended first production candidate:

- `SWETR=1`
- `SWMETDETAIL=0`
- `SWDIVIDE=0`
- `SWINTER=0`
- `SWEVAP=1`
- `SWREDU=0`

Publish all three atmospheric demands needed by downstream owners: potential transpiration, potential bare-soil evaporation and potential pond evaporation. Reuse the qualified F-WOF18 transpiration semantics, but re-admit source on current canonical lineage rather than merging its historical branch. Independently qualify the additional `peva/epond` formulas.

### Slice E2: transactional soil-evaporation reduction

Add `SWREDU=1` and `2` behind one reduction interface with option-specific state. Prove retry rollback and restart continuation before composition.

### Slice E3: daily/event interception methods

Add `SWINTER=1` and `2` as explicit source-window/event processors. Preserve nonlinear aggregate semantics and make forcing-window provenance explicit.

### Slice E4: Rutter interception state and event seam

Add `SWINTER=3`, optional `sicact`, event-bound output and atomic crop-capacity/state composition. Qualify `siccaploss` reference behavior explicitly.

### Slice E5: Penman-Monteith and detailed meteorology

Qualify `SWETR=0`, `SWMETDETAIL=1`, `SWDIVIDE` variants and PM-specific parameters/equations independently. Weather-file parsing remains outside the kernel.

### Slice E6: broader cross-physics composition

Only after owner qualifications: snow interaction, broader root-uptake options, crop variants and MultiSWAP execution-class composition.

## Invariant audit

- **1 one kernel:** PASS by contract; no ET-specific kernel fork.
- **2 kernel free of I/O:** PASS; weather files/cursors stay in adapters/runtime.
- **3 explicit data separation:** PASS; parameters, forcing, persistent state, results and scratch are separated.
- **4 compact persistent state:** PASS; only `ldwet`, `spev/saev`, `sicact` where active, plus externally owned crop/hydraulic state by reference.
- **5 scratch per worker:** PASS; PM/interception/reduction algebraic temporaries are worker-local.
- **6 scalable layout:** PASS; topology-specific execution classes remain possible.
- **7 transactional timesteps:** PASS by required contract; legacy pre-retry mutation is explicitly rejected as target architecture.
- **8 cheap replay/warm start:** PASS; stateless demand is replayable and stateful processes restart from committed snapshots.
- **9 generic time:** PASS; daily source records are forcing/event semantics, not kernel cadence.
- **10 flexible coupling windows:** PASS; no ET contract requires midnight boundaries.
- **11 coupling core functionality:** PASS; ET exposes clean trial results and state suitable for rollback/replay.
- **12 groundwater interface:** N/A directly; ET does not alter groundwater interface contract.
- **13 absolute mass conservation:** PASS by exactly-once flux/storage identities.
- **14 interface sensitivities:** N/A directly; ET does not consume solver Jacobian internals.
- **15 coupling cost:** PASS; ET contract does not require duplicate full-column runs.
- **16 MultiSWAP primary:** PASS; optional state and shared parameter references support batching.
- **17 MODFLOW tiling:** PASS; ET knows nothing about cell fractions.
- **18 deep vadose:** N/A.
- **19 component transition mass:** PASS by explicit accepted mass receipts; no hidden ET storage migration.
- **20 alternate soil-water solvers:** PASS; actual evaporation uses a solver-neutral top-boundary interface.
- **21 reuse SWAP physics:** PASS; crop and root-uptake owners are reused, not duplicated.
- **22 no HeadCalc internals:** PASS and explicit prohibition.
- **23 physics versus solver policy:** PASS; ET options stay physical configuration, retry policy stays runtime/numerical policy.
- **24 bounded cost:** PASS architecturally; ET process states do not force unbounded solver work.
- **25 reference mode:** PASS; exact B1.10 source remains oracle authority and broader methods require qualification.
- **26 diagnostics:** PASS by required process diagnostics and transaction receipts.
- **27 optionality scales with use:** PASS; option-specific states are not allocated when inactive.
- **28 runtime/coupler composition:** PASS; ET has no tile/coupler knowledge.
- **29 no silent dependencies:** PASS; day, file, solver-global and crop-owner assumptions are made explicit or removed.
- **30 audit every change:** PASS for this readiness decision; production implementation remains a separate qualified unit.

## Readiness decision

The process boundary, true persistent ET/interception state, forcing ownership, generic-time semantics, hydraulic interface, transaction rules, exactly-once mass contributions and migration order are sufficiently source-bound to admit a **restricted structural candidate**.

Decision:

`QUALIFIED_ET_MIGRATION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE`

This is **not** a qualification of full ET physics. In particular it does not newly qualify Penman-Monteith, interception methods 1/2/3, SWREDU 1/2 production code, broader root-water-uptake physics, arbitrary crop cadence, or any historical F-WOF18 branch merge.

Recommended next owner: a separate F-PM production-candidate workunit implementing Slice E1 on the current canonical lineage, followed by independent qualification.