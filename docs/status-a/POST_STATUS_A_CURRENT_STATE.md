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

The INT13 work branch composes Rutter canopy storage and INT12 source-window progress into the production FMR physical-state candidate. Reconciliation against the recovered exact SWAP 4.3.1/B1.11 `MOD_meteo.f90` showed that the previous candidate used the wrong SWAP 4.2.0 exponential `fimin` equation. The current local candidate instead integrates B1.11's piecewise-constant fill/dry flux regimes and removes `fimin` from the forcing contract. Local O0/O2 source-window, production-transaction and capacity-event tests pass. Targeted Actions run `37271615834` passed the INT13 physics/source-window/retry/restart and production FMR gates on candidate commit `4403db7996ec49b910a419d53c7efe2b4cd75102`; historical run `37268521592` tested the superseded candidate. This qualifies the bounded candidate, but `SWINTER=3` remains unadmitted pending canonical integration. The source correction is recorded in `integration/audits/F-MIG431-INT13_SOURCE_RECONCILIATION_ADDENDUM.md`. The bounded constant-surface-irrigation extension passed INT13 Actions run `37276517425` and companion PPA-WU01 run `37276517357` on commit `6f6eba2241b662cf0d3c1126bd21a63845b6ee41`, covering both B1.11 `ISUA` modes at the tested low-rate vector. Higher throughfall reached the separate Reference Richards dynamic-head surface-head derivative error and remains out of scope, as do irrigation scheduling, sprinkling, Snow, Black/Boesten, macropore and surface-water/RFM combinations. See `integration/audits/F-MIG431-INT13_STATUS.json`.


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

## PPA-WU05-MIGMAC02 dynamic crack geometry

PR #1019 canonically admits Kim clay direct option-1 shrinkage in the
existing serialized Reference Richards macropore chain. Candidate moisture and
accepted crack history derive subsidence, capacity, domain bottoms and top crack
area. Existing exchange/top-input/rapid-drain owners consume that geometry;
displacement enters the matrix receipt before acceptance. Retry and restart
retain the accepted boundary. The explicit provider disables the inherited
short-step source-freezing heuristic when geometry can change.

The controlling scope, exact source postimages, independent oracles, O0/O2,
A/B/A, smaller retry, restart, water closure and preservation evidence are in
`integration/audits/PPA_WU05_MIGMAC02_QUALIFICATION.json` and
`docs/audits/PPA_WU05_MIGMAC02_CLOSEOUT.md`. Canonical admission is recorded in
`integration/audits/PPA_WU05_MIGMAC02_STATUS.json` with canonical merge `957b87d69888f1eb7ef5671f441563bd9b798687`. Peat/alternate fitting and additional surface/drain compositions
remain outside this bounded admission. Frozen Status A is unchanged.

## PPA-WU05-MIGMAC03 peat and rigid constitutive extension

Direct regular Hendriks and three-segment peat laws, including alternating
rigid/peat compartment profiles, are canonically admitted by PR #1020 in the existing Reference
Richards macropore geometry/transaction chain. Optional typed law selectors
preserve implicit Kim callers. No new water or restart owner is introduced.
[Closeout](../audits/PPA_WU05_MIGMAC03_CLOSEOUT.md) bounds parameter validity and
claims; `integration/audits/PPA_WU05_MIGMAC03_STATUS.json` records admission.
Parameter fitting, mixed Kim/peat runtime and new mixed-law rapid-drain reference
construction remain separate gaps. Frozen Status A is unchanged.

## PPA-WU05-MIGMAC04 characteristic-point shrinkage input

Kim clay input2 and the uniquely identifiable regular Hendriks peat input2
branch are canonically admitted by PR #1021 as preparation of existing constitutive carriers.
Clay preparation is analytic; peat preparation uses bounded, bracketed root
finding against the exact B1.11 equation. No runtime/state/mass owner is added.
[Closeout](../audits/PPA_WU05_MIGMAC04_CLOSEOUT.md) bounds input validity, numerical
criteria and non-identifiable cases; `integration/audits/PPA_WU05_MIGMAC04_STATUS.json`
records admission. Ambiguous fits and new mixed-law/drain compositions remain
outside this scope. Frozen Status A is unchanged.

## PPA-WU05-MIGMAC05 mixed constitutive Reference profiles

PR #1022 canonically admits mixed Kim/direct Hendriks, Kim/three-segment peat and
rigid/Kim/peat qualification in the existing serialized Reference geometry chain.
This later admission closes the mixed Kim/peat runtime gap named in MIGMAC03/04.
No production source or physical owner changes. Prepared carriers, accepted history,
wetting displacement, retry, A/B/A and restart pass at O0/O2. Supplied-coefficient
two-domain drainage composes; new mixed-law reference KD derivation remains open.
See [closeout](../audits/PPA_WU05_MIGMAC05_CLOSEOUT.md) and its pinned qualification.
Wider drain/surface compositions and whole-model equivalence remain excluded.
Frozen Status A remains unchanged.

## PPA-WU05-MIGMAC06 hydrostatic rapid-drain reference KD

PR #1023 admits explicit pre-trial preparation of the existing immutable reference
KD from hydraulic-owner supplied hydrostatic moisture and mixed constitutive laws.
This closes the bounded mixed-law reference construction gap named in MIGMAC05.
The source reference geometry, node tolerance, saturation cap and rigid barrier
rules are preserved. Zero connectivity disables rapid drainage. No new water,
state or restart owner is added. Supplied and adapter-derived Reference results
agree at O0/O2, including wetting and two-domain rapid drainage; retry and restart
pass. [Closeout](../audits/PPA_WU05_MIGMAC06_CLOSEOUT.md) pins source and gates.
Multiple/within-compartment drains, covering-layer reference preparation and
additional surface/whole-model compositions remain excluded. Frozen Status A
and the incomplete broad migration denominator remain unchanged.

## PPA-WU05-MIGMAC07 within-compartment rapid drainage

PR #1024 admits one rapid-drain level inside an FMR compartment using the source
VOLUNDR uniform-volume-density equation. The A10 aligned-only restriction and
MIGMAC06 within-compartment exclusion are superseded within this bounded route.
The shared geometry helper retains boundary snapping, current main-domain capacity,
active cutoff and one external rapid-drain receipt. No accepted subcell state is
introduced. Partial-level A10 and mixed-law Reference retry/restart, wetting,
water closure and supplied/derived KD equivalence pass at O0/O2.
[Closeout](../audits/PPA_WU05_MIGMAC07_CLOSEOUT.md) pins source and qualification.

The exact source prepares only one rapid-drain reference level; RAPIDDRAIN returns
for domains other than main domain1 and uses one selected NumLevRapDra. Multiple
simultaneous rapid-drain levels are therefore future functionality, not a missing
implemented B1.11 capability. Ordinary multilevel matrix drainage is separate.
Covering-layer reference preparation, wider source-relevant surface compositions
and whole-model equivalence remain separate migration work. Frozen Status A and
the incomplete broad migration claim remain unchanged.

## PPA-WU05-MIGMAC08 rigid covered reference preparation

PR #1025 admits hydrostatic reference-KD preparation for an explicit rigid cover
with exactly zero above-top static macropore capacity. Existing covering matrix
transfer remains the covered-input owner; surface-connected A9 precipitation is
absent there. Invalid cover selectors/capacity fail without KD mutation. Source
section-D and independent covered reference geometry agree. Mixed-law Reference
wetting, partial rapid drainage, prepared carriers, supplied/derived KD identity,
retry, A/B/A and accepted restart pass at O0/O2, with preceding route preservation.
[Closeout](../audits/PPA_WU05_MIGMAC08_CLOSEOUT.md) controls source and qualification.

Earlier covering-reference exclusions are superseded only for this rigid route.
Nonrigid covering reference preparation still needs source relevance/ownership
reconciliation; wider source-relevant surface compositions and whole-model
equivalence remain outside this admission. Frozen Status A remains unchanged;
broad migration is still incomplete.

## PPA-WU05-MIGMAC09 source covering compartment mask

PR #1026 admits the source mask above IcTopMp independently of covering soil
shrink law. Source initialization zeros static volume and all domain fractions
there; MPVOLUME excludes those cells. Production candidate geometry now receives
the actual top node. Reference preparation checks zero static/domain capacities,
replacing MIGMAC08's rigid-selector restriction. Nonzero accepted covered crack
volume fails without accepted-state mutation. Covering matrix transfer retains
its owner; no new surface forcing, persistent state or solver policy is added.

Nonrigid covered mixed-law dry/wetting/partial-drain Reference trials, prepared
carriers, supplied/derived coefficient identity, retry/A-B-A/restart and O0/O2
pass. All affected pure/provider and A8/A10/MIGMAC01/PERCH20 gates pass. Exact
section-D source and independent reference geometry agree. See
[closeout](../audits/PPA_WU05_MIGMAC09_CLOSEOUT.md) and pinned qualification.
Earlier nonrigid-cover reference exclusions are superseded for this source mask;
a separate covering macropore crack law is not unported B1.11 functionality.
Wider source-relevant surface compositions and whole-model equivalence remain
outside admission. Frozen Status A is unchanged; broad migration is incomplete.


## Bounded frost hydraulics: PPA-WU05B (2026-10-05)

The B1.11 temperature-to-K/dKdh modifier is canonically admitted through PR #1018,
merge `5272ac9192ec1065dbe2432f73d1f1b4394437e0`. Dedicated run `37324712595`
passed frost effect/provider/runtime/restart/retry and the complete current-canonical
preservation runner at O0/O2 on exactly the tree admitted by that merge.

Scope is serialized Reference Richards with the existing restricted sensible-temperature
owner and prescribed bottom mode 2 with zero bottom flux. Water content, capacity,
water mass and committed restart ownership remain unchanged. Frost root stress,
FrozenBounds, snow/macropore/drainage/coupling combinations, temporal history,
trajectory direction, sensible boundary carriers and new latent-heat/ice physics
remain excluded. This closes the bounded hydraulic slice, not aggregate frost migration.

See [canonical closeout](../audits/PPA_WU05B_CANONICAL_CLOSEOUT.md) and
`integration/audits/PPA_WU05B_CANONICAL_ADMISSION.json` for scope and evidence.


## Matrix salinity in Jarvis: PPA WU05 E (2026-10-05)

PR #1015, canonical merge `cb841851db6a4f459835b4943cf442595898ecd3`, independently admits the selected matrix dissolved-salt transport owner, Maas-Hoffman response and its Feddes/Bartholomeus/Jarvis composition. This extends the earlier bounded D2 admission with selected matrix salinity; the historical D2/D3 closeout above describes its original denominator. The sole root-water sink is retained, while salt mass commits/discards and restarts with matching accepted water state.

All 19 named current-source local qualification/preservation gates pass after reconciling admitted frost. Seven actual mixed stress cases, three top boundary cases, O0/O2, retry and separate-process restart are covered. The admitted merge source/test subtrees exactly match execution, with 1,024 verified manifest entries. Frost, Rutter, Walsum and MIGMAC07/08/09 remain preserved.

Admission excludes salt/frost, salt/Rutter, salinity/Walsum, osmotic-head mode, sorption/decomposition, aquifer/groundwater salt state and full legacy or seasonal field equivalence. See [canonical closeout](../audits/PPA_WU05E_CANONICAL_CLOSEOUT.md) and `integration/audits/PPA_WU05E_CANONICAL_ADMISSION.json`. Frozen Status A remains unchanged.

### PPA-WU05B2 empirical root frost admission (2026-10-05)

PR #1030 / merge `3039e573229b2bf19747f713084ea7a19cb48ed0` admits the explicit
macro-root subzero cutoff with uncompensated, Jarvis and Walsum application paths.
Local O0/O2 runtime, actual thaw, accepted uptake, direct refinement, fresh-worker
restart, active salinity preservation and full current-canonical preservation pass.
Production source identity is exact. Actions confirmation was queued and is not
claimed successful. Local full/half temperature budgets do not imply cumulative
1e-6 C accuracy; the documented horizon comparison bound is 1e-4 C. Joint salt/frost,
Bartholomeus/frost and FrozenBounds remain excluded. The next source-bound boundary
review is `docs/audits/PPA_WU05B_FROZEN_BOUNDS_REASSESSMENT.md`.
