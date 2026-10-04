# SWAP5 post-Status-A current canonical state

Date: 2026-10-01

This page is the current development-state supplement to the frozen Status-A review authority. It does **not** retroactively expand the first colleague-review denominator fixed on 2026-09-16. It records later canonically admitted capabilities that are relevant when deciding what may be developed next.

## Authority boundary

- frozen Status-A review authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- frozen scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- F-GC49D canonical merge: `ac3f789c51dad9806020c37db4f7666b9f18e66f`
- F-GC49D canonical closure: `96f7547b9e618863bc162266137abc872c376734`
- reconciled canonical preimage for this snapshot: `20d34024cfe4b981b6c00d5042bdf366f8aae830`

The canonical delta from the F-GC49D closure to the reconciled preimage contains later work but no groundwater production/runtime/test/workflow dependency overlap with F-GC49D. The F-GC49D admission therefore remains the controlling current groundwater authority on this snapshot.

## Current post-Status-A groundwater capability

The post-Status-A canonical line now contains a concrete SWAP5-MODFLOW6 production application chain beyond the structural Groundwater Coupling v1 gateway that belonged to the frozen Status-A denominator.

The admitted chain includes:

1. F-GC33 linear groundwater-response evaluation and re-anchoring authority;
2. F-GC34 typed MODFLOW6 package binding/publication;
3. the live XMI package and prepared-solve backend materialized through the later F-GC chain;
4. F-GC39 prepared-solve coupling-service ownership;
5. F-GC40 conservative cell aggregation for multiple SWAP tiles;
6. F-GC41 whole-window acceptance, retry and publication ordering;
7. F-GC42 service composition;
8. F-GC43 production FMR/SWAP participant binding;
9. F-GC44 through F-GC47 real-application qualification, including N:1, multi-cell and mixed topology;
10. F-GC48 generic groundwater-topology composition;
11. F-GC49A production application-plan materialization;
12. F-GC49B production FMR participant registry with opaque nonrecycled handles;
13. F-GC49C topology-agnostic production coupling-window service;
14. F-GC49D production FMR cross-language application context and ABI.

F-GC44 through F-GC47 **qualification C bridges remain test fixtures**. Their scientific/application qualification evidence is admitted, but those bridges are not promoted into the production FMR ABI. F-GC49D supplies the production cross-language boundary instead.

## Current ownership contract

The following ownership rules are current and must survive later integration work:

- SWAP/FMR owns committed state, candidate state, real corrector execution and SWAP publication;
- F-GC40 remains the authority for N:1 cell aggregation;
- F-GC33 remains the authority for linear-response evaluation and re-anchoring;
- external Fortran mass ledgers remain ledger owners;
- `Modflow6PreparedSolveSession` owns the live MODFLOW6/XMI prepared-solve and timestep-finalization lifecycle;
- the generic F-GC49C service orchestrates one coupling window without owning SWAP physics or raw XMI arrays;
- publication order is MODFLOW `finalize_time_step`, then SWAP commits, then ledger commits;
- failure after MODFLOW timestep publication is a durability/restart-class failure, not a rollback-safe smaller-window retry;
- predictor/corrector product orchestration remains above SWAP5, in the iMOD Coupler layer.

## Qualified production envelope

F-GC49D qualified one production mixed-topology application window with:

- two real FMR participants coupled N:1 to one groundwater cell;
- one real FMR participant coupled 1:1 to a second groundwater cell;
- one live MODFLOW6 6.8.0 prepared solve for both cells;
- conjunctive convergence requiring MODFLOW nonlinear convergence and every individual cell residual within tolerance;
- exactly one successful window publication and fail-closed protection against context reuse.

The F-GC49D owner qualification used surface `cd498b76778f4ecde8f9fed17aeb2b3c3ef4990b`; owner run `35352680601` and independent F-VQ124 run `35352680593` both passed before canonical admission.

## What is not yet admitted

The following remain separate capabilities and must not be inferred from F-GC49:

- integration into the actual iMOD Coupler product driver/configuration lifecycle;
- broader prescribed-head, timestep or groundwater-physics envelope qualification;
- a generic backend abstraction beyond the admitted MODFLOW6 path;
- distributed atomicity across independently durable external systems;
- heterogeneous N:1 hydrological transferability.

The last item belongs to the separate SCALE scientific workstream. Technical N:1 support is not evidence that heterogeneous columns may be physically aggregated without material error.

## Next bounded development step

The next groundwater software capability may target **iMOD Coupler production integration**: compose the admitted F-GC49 production ABI with the actual iMOD Coupler driver lifecycle while preserving all ownership rules above. This must be a new workunit; F-GC49 itself is closed and has no Stage E.

Any later numerical/physics-envelope expansion should follow as a different bounded capability after product integration, rather than being mixed into the driver integration work.


## Current post-Status-A Ribasim surface-water capability

Canonical now also contains a bounded live SWAP5-Ribasim surface-water application profile.

The controlling authority chain is:

1. SW-RIB-SWM01 research closeout for responsibility decomposition and retirement analysis;
2. F-APP09 plus F-VQ128 for the SWAP-side external-surface-water transaction participant;
3. F-CI109 canonical admission of that exact SWAP-side production postimage;
4. SW-RIB-ADM01 G5B/G6/G7 for real Ribasim v2026.1.2 realization, provenance and live application qualification;
5. canonical ADM01 application closeout at `c9c0352b2310d3f3b5ae2a29c3d62c72a0fbb5d0`.

The admitted application profile is `RIBASIM_EXTERNAL_SECONDARY_STATE_V1`.

Within that profile:

- Ribasim is the sole accepted owner of the represented secondary surface-water storage and level;
- SWAP5 receives one typed accepted external surface-water head for one `EXTENDED_SIGNED` drainage-response level;
- SWAP5 retains the signed drainage/infiltration constitutive physics;
- positive drainage and negative infiltration are supported;
- a mismatch between requested and physically realized transfer prevents commit and requires discard/recomposition from the same accepted origins;
- availability-limited infiltration is not accepted by clipping one side after SWAP acceptance;
- exactly one final accepted commit is published for an accepted coupling window;
- `RIBASIM_NATIVE_GEOMETRY_V1` is the default surface-water geometry contract.

This admission does not remove the standalone F-CI52 restricted fixed-weir capability. The application profiles are mode-exclusive for the same physical surface-water store: internal SWAP fixed-weir state ownership and external Ribasim state ownership may not both be authoritative.

The following remain outside the admitted Ribasim profile:

- multilevel external surface-water exchange;
- automatic `SWMAN=2` production runtime;
- top-runoff and rapid-drainage production binding;
- exact nonlinear legacy `SWQHR1` numerical parity;
- whole-file retirement of `surfacewater.f90`;
- combined SWAP5 + MODFLOW6 + Ribasim triangle admission.

The legacy `STTAB` storage relation is not assumed to map exactly to a Ribasim Basin profile between its knots. Q1H provides a separately named epsilon-controlled legacy-emulation route, but the default coupled production profile uses Ribasim-native geometry because Ribasim owns the surface-water state.


## Current post-Status-A macropore capability

Canonical now also contains a bounded production macropore route through serialized single-column FMR.

The controlling authority chain is now:

1. PPA-WU05-A8, canonically admitted by PR #923 at `9bad713b0d2ab24d40fcf937d11c850d3fb52a22`, for the bounded serialized Reference-Richards macropore runtime and continuation-state contract;
2. PPA-WU05-A9, canonically admitted by PR #926 at `243f43cccd817c1bb175f14faa64efd574d6d3ca`, for the source-faithful surface-connected macropore top-input carrier;
3. PPA-WU05-A10, canonically admitted by PR #928 at `190dad36a821f3a43f78f00fccf827c58cacedb6`, for source-bound main-domain rapid drainage. Post-merge A10 preservation run `36829313469` passed on that exact canonical merge.

The admitted envelope is deliberately narrow:

- standard `swmbf=1` route;
- Reference Richards only;
- immutable FMR macropore configuration;
- dynamic hydraulic views from accepted matrix/macropore state;
- outer source/sink coupling while the inner Richards request keeps `macropore_active=.false.`;
- transactional candidate-only publication;
- committed-state persistence/restart for the seven continuation fields;
- serialized single-column execution;
- explicit source-faithful net rainfall, net irrigation and melt input for surface-connected macropores;
- explicit separately owned lateral overland/infiltration-excess macropore input;
- current accepted macropore top geometry for source partitioning;
- capacity limitation, redistribution and returned-surface receipt through the admitted A6 logic;
- accepted macropore top input booked exactly once in whole-column external mass accounting;
- main-domain rapid drainage through the source-bound A6 RAPIDDRAIN formulation;
- dynamic rapid-drain water level, saturated top fraction, ponding, active bottom and storage views;
- exact below-drain volume reconstruction for drain levels aligned to compartment boundaries;
- accepted rapid drainage booked exactly once as external whole-column outflow.

The admission does not include inference of source components from generic FMR `top_flux`, independent ponding/runon macropore source terms, simultaneous A9 ownership with Snow/Black/Boesten/fixed-weir surface-water routes, covering-layer or perched-zone macropore physics, arbitrary within-compartment rapid-drain levels, multiple rapid-drain levels, fixed-weir/Ribasim ownership of the same rapid-drain receipt, within-corrector dynamic crack-geometry feedback, RossFast, or parallel/concurrent MultiSWAP macropore execution.

This capability is post-Status-A and does not change the frozen Status-A denominator.


## Current post-Status-A Bartholomeus oxygen capability

Canonical now contains the bounded PPA-WU05-C3A Bartholomeus oxygen-stress route admitted by PR #962 at `179673b16b84bc48fa5e0e83341a8a8e80b2211a`. Exact candidate `63b7c982d12a7df8f6f933d32fc382fbcc02bb67` passed final qualification run `36972631192`, including the actual typed Reference application, complete unchanged B1.11 assembled oracle and affected current-canonical/shared-backend preservation.

The admitted envelope is oxygen mode 2/type 1 with analytical MvG REFERENCE waterfilm in the homogeneous serial typed Fortran Reference application, bottom 2 or 7 and the existing restricted thermal owner. Oxygen OFF remains exact; unsupported active compositions fail closed. Oxygen adds no accepted continuation state, checkpoint/restart field, solver ABI or water ledger.

Groundwater-coupled, macropore, snow, drainage-response, elastic, hysteretic, tabular, PRACTICAL/WFT300 and worker-parallel oxygen remain outside the admitted envelope. This admission also does not close salinity, frost, compensation or MICRO/JvL gaps and does not alter the frozen Status A denominator. See `docs/audits/PPA_WU05C3A_CLOSEOUT.md`.


## Current post-Status-A interception capability

Canonical now contains the completed non-Rutter SWAP 4.3.1 interception family for `SWINTER=1/2`.

The controlling authority chain is:

1. PPA-WU04, which reconstructed the state/transaction contract and identified `SWINTER=1` as Von Hoyningen-Hune/Braden, `SWINTER=2` as Gash and `SWINTER=3` as the separate stateful Rutter capability;
2. F-MIG431-INT12-P0 for method-neutral immutable source-window interception aggregates with accepted progress, retry and restart provenance;
3. F-MIG431-INT12-C for the existing `SWINTER=1` daily aggregate route;
4. F-MIG431-INT12-D, PR #1010, canonical merge `23a5768771a93a338daba78ab117682ee1e459f2`, for `SWINTER=2` Gash daily `SWMETDETAIL=0`;
5. F-MIG431-INT12-E, PR #1011, canonical merge `0fc427f63cffab666014129641c864ccd65983f0`, for `SWMETDETAIL=1` non-Rutter record continuation shared by `SWINTER=1/2`.

The admitted semantics are:

- `SWINTER=1` and `SWINTER=2` interception physics produce source-window aggregates rather than persistent physical canopy-storage state;
- Gash preserves the B1.11 equation and legacy branch ordering, including the historical `grai` saturation comparison;
- numerical retries do not reevaluate nonlinear daily interception physics on smaller hydraulic spans;
- accepted source-window progress is transactional and restartable through P0;
- daily rain/sprinkling partition, the legacy DivIntercep threshold, snow-disable gate and wet-canopy potential-transpiration composition are qualified;
- detailed meteorology uses record-weighted daily interception and an explicit accepted `restint` continuation within the source day;
- detailed `restint` is reset to zero at every new detailed-meteo source day and is therefore not physical or multi-day canopy storage;
- mid-day restart persists source-day identity, next-record cursor and accepted `restint`;
- rejected trials advance neither interception progress nor detailed-record continuation state.

Final INT12-E admission-head qualification passed in run `37152387427`; INT12-D preservation passed in `37152387486`; P0 preservation passed in `37152387442`.

Within the non-Rutter `SWINTER=1/2` interception scope, no known selector, retry, restart or precipitation-partition capability gap remains. `SWINTER=3` Rutter remains a separate stateful capability and is not subsumed by this closure.

The INT13 work branch now composes Rutter canopy storage and INT12 source-window progress into the production FMR physical-state candidate. Local O0/O2 source-window and production-transaction tests pass, including Richards retry identity, rejected-trial rollback, restart carrier registration, root-sink composition and hard mass closure. This is work-branch evidence only: `SWINTER=3` is not yet canonically admitted, and the family must not be described as fully closed until persisted qualification and canonical merge. The bounded local envelope excludes irrigation/sprinkling, Snow, Black/Boesten, macropore and surface-water/RFM combinations; see `integration/audits/F-MIG431-INT13_STATUS.json`.


## Compensated root uptake: PPA-WU05-D2/D3 (2026-10-04)

Jarvis (PR #1012, canonical merge `4fd57c8c8`) and Walsum (PR #1013,
canonical merge `a34c87db9`) are separately admitted within the existing Feddes
root-sink chain, optionally composed with independently admitted Bartholomeus
oxygen. The sole root-water mass owner remains unchanged. Accepted transpiration
now reports the final transformed sink through the existing transaction result.
Walsum derives its dynamic ALPHACRIT from typed current centimetre geometry,
including the full bottom of a partially rooted node.

See [canonical closeout](../audits/PPA_WU05D_D2_D3_CANONICAL_CLOSEOUT.md) for
qualification, exact scope, legacy-source limitations and the remaining D4/D5 gaps.
This does not admit salinity, frost, MICRO or general coupling combinations.
