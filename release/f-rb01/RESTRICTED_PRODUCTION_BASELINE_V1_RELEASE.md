# SWAP5 Restricted Production Baseline V1

## Release classification

F-RB01 qualifies a deliberately restricted SWAP5 production baseline. The fixed required denominator contains 15 capabilities and all 15 passed the decisive release qualification. This is a bounded production claim, not a claim that SWAP5 already reproduces every SWAP 4.3.1 option or every intended future application.

Decision: `QUALIFIED_SWAP5_RESTRICTED_PRODUCTION_BASELINE_V1_READY_FOR_RELEASE_AUTHORITY`

## Exact authority

Scientific production source authority is `integration/f-ci-canonical@0aeb0a2ed4096e1f9493d3dabc70962ea5270182` with source tree `8ceeb70a64012631ebba295f5c045ea908b0681f` and reference tree `9d08625217d7c0a7385df9da6a04183bcd9cb9e6`.

The frozen F-RB01 release candidate is `0c4f7eee9fcadd49268350e477799b5a34e30e3b` with tree `3716898eae3c33bf62616e43a2690e9aeb71d434`. F-RB01 changed release evidence and qualification harnesses only. It did not change production `src` or `reference` authority.

The decisive workflow is run `34569690664` on workflow head `05092df17222c1761b42940bca369208ae009654`. It completed successfully on Ubuntu 24.04 with GNU Fortran 13.3.0. The retained Actions artifact is `10187339980`, digest `sha256:e28c99c248256e6cf7a230c06be51ca3ba0653d6ea1c9ab30e8272c1740834a3`.

## What RB1 releases

RB1 releases the single SWAP5 kernel over generic `[t0,t1]` intervals with explicit separation of parameters, committed state, forcing, numerical configuration and results. Transaction semantics are checkpoint, trial/retry, commit or rollback. Rejected trials do not mutate committed state or the authoritative water ledger. Hard mass conservation remains non-negotiable.

The soil-water production route is the Full Richards `REFERENCE` route within the frozen B1.10/default-MVG profile. The restricted temporal acceptance machinery is included only under its admitted scientific contract. Where `H_budget` is exercised it must be explicit, finite and positive; RB1 does not invent a universal application accuracy budget.

Standalone operation is the N=1 use of the same kernel/runtime contracts used by MultiSWAP. RB1 includes restricted serialized real-physics MultiSWAP and restricted parallel V1 execution with 2 or 4 workers. Heavy runtime/solver scratch remains worker-owned rather than one heavyweight solver instance per logical column.

The released process subset includes reference ET, restricted Macro/Feddes drought-only precomputed-QROT root uptake, exact-runtime-forcing actual-transpiration attribution, the qualified root-active parallel profile, and stateless `SWINTER=0`, `SWREDU=0` surface evaporation. The accepted external solver top flux remains the authoritative top-water mass booking.

RB1 includes committed-boundary restart for the serialized profile and qualified parallel continuation with 2-to-4 and 4-to-2 worker changes. Restart records do not persist Newton, Jacobian, worker, forcing-cache or warm-start scratch.

A restricted serialized single-level positive DIVDRA path is admitted as optional capability, outside the 15-item required denominator.

## Decisive evidence

The release suite passed the fixed 15-capability denominator, all 30 architecture-invariant audits with zero applicable failures, hard mass gates, transaction and rejected-trial checks, deterministic replay, negative fail-closed cases, committed-boundary restart, serialized/parallel composition, root-active parallel qualification, and restricted surface-evaporation preservation.

The current serialized/restart replay includes irregular batch sizes 1, 2, 7, 8, 17, 31 and 32; exact lineage/revision/time continuation; exact interval-mass continuation; continuous-versus-restarted endpoint identity; deterministic replay; malformed-state and atomicity negatives; and current ET runtime preservation.

The parallel root replay passed O0 and O2, exact O0/O2 output identity and hard mass. Its independent runner internally enforces held-out positive cases, input-order independence, rejection isolation, unsupported-profile rejection, invalid/non-finite QROT rejection, worker-count rejection and canonical publication order.

The parallel restart replay passed O0 and O2, exact O0/O2 identity and hard mass. Its independent runner internally enforces serialized-origin restart, 2-worker and 4-worker origin restart, 2-to-4 and 4-to-2 continuation, reverse/interleaved record order, negative restart-state checks and prior parallel preservation.

The surface-evaporation replay has exact observable identity to the frozen F-CI41P/F-VQ56 scientific authority, O0/O2 identity, committed-state immutability, A-B-A determinism and no second authoritative mass booking.

## Performance claim

RB1 does not define an artificial absolute runtime SLA. Existing F-PE evidence shows useful restricted parallel scaling under its measured fixtures and preserves negative tail evidence. F-PE11 establishes a local surface-materialization allocation/runtime improvement, but RB1 does not convert that into a whole-SWAP or MultiSWAP speedup claim.

No universal p50/p95/p99 difficult-column distribution, portable peak-RSS guarantee, universal speedup or worker-count recommendation beyond the admitted 2/4-worker profile is claimed. The surface-evaporation call-local allocation work is scientifically closed but broader throughput/scaling remains a separate performance workunit.

## Explicit exclusions

RB1 does not release active WOFOST/crop lifecycle runtime, parallel active DIVDRA, active macropores, broad frost/snow physics, soil temperature, solute transport, unqualified irrigation composition, `SWKIMPL=1`, other `SWSOPHY` profiles, `SWINTER=1/2/3`, `SWREDU=1/2`, oxygen/salinity/frost/compensation/MICRO/Jong-van-Lier/macropore root uptake, bottom-boundary modes outside the frozen profile, worker counts other than 2 or 4 for restricted parallel execution, arbitrary composition of separately admitted options, mid-transaction restart, trial-state persistence or restart file-format/cross-version migration.

RossFast and other alternative/reduced soil-water solvers remain research-only for production. `BALANCED`, `THROUGHPUT` and `FALLBACK` execution classes are not RB1 production policies. Broader SWAP-MODFLOW predictor-corrector application release and application-class groundwater-head accuracy budgets require separate qualification.

RB1 is not Status A or Status AA certification and is not validation for every application domain.

## Governance after closeout

The denominator is frozen. Later capabilities default to a next release and do not retroactively enlarge RB1. Any production-source or reference change requires a new governed candidate and new release qualification rather than silently changing this baseline.

F-RB01 reuses F-TB01/F-TB02 authority and contributes bounded release fragments for later testbank adoption. It does not create a second central test-governance system or modify the F-TB01 central registry.
