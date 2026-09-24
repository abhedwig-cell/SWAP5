# SWAP5 post-Status-A current canonical state

Date: 2026-09-18

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
