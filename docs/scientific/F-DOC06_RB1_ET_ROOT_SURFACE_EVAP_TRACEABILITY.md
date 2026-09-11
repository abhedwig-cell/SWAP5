# F-DOC06 - RB1 ET, Root and Restricted Surface-Evaporation Traceability

## Scope

F-DOC06 populates bounded traceability for exactly three frozen `SWAP5-RB1-v1` capabilities:

1. `RB1-ET-ROOT-SERIAL`;
2. `RB1-ROOT-PARALLEL`;
3. `RB1-SURFACE-EVAP-RESTRICTED`.

The exact upstream documentation authority is `F-DOC05@919f228d8aedc1029b5080bb019fbe61d2e1d7c6`. The frozen RB1 scientific source remains `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`; RB1 qualification and final release metadata remain `aeb74560d801c4ac7314df7b8845fcc5daf8bba6` and `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0` respectively.

F-DOC06 is documentation and traceability only. It changes no production source, reference data, process physics, soil-water solver, scientific tolerance, acceptance threshold, performance policy or RB1 release denominator.

## Reference ET to restricted root uptake

The frozen serial chain is intentionally compositional rather than a new ET/root monolith. `mod_reference_et_demand_process` and `mod_fmr_reference_et_demand_binding` provide the restricted reference potential-ET demand over a generic contained interval. The authoritative potential-transpiration handoff is then explicit through `mod_fmr_reference_et_ptra_root_input_binding`, the crop/root input contract and `mod_fmr_reference_et_root_uptake_composition` before the restricted root-water-uptake process is evaluated.

F-CI27 is useful but deliberately insufficient by itself for the complete RB1 ET/root claim. Its admitted scope was potential ET rates over generic contained time intervals, and its status explicitly said that root uptake was not yet bound and ptra ownership was not yet reconciled. F-DOC06 therefore does not retroactively reinterpret F-CI27 as root-process qualification.

The later F-CI34/F-VQ50 lineage supplies the exact-runtime-forcing-bound root-uptake attribution evidence used by RB1. Its scientific gates include forcing-provenance checking, a real HeadCalc root oracle, O0/O2 identity, exact attribution semantics, active-zero availability, fail-closed unavailability for root-inactive/noncommitted cases, no second mass booking and hard mass balance. F-DOC06 binds that lineage only as it is preserved in the frozen RB1 scientific source and release. Historical wording that still required a later governance replay is not upgraded into a broader standalone F-CI34 claim.

The resulting RB1 capability remains bounded to the released drought-only precomputed-QROT profile. It does not imply crop-lifecycle advancement, arbitrary time-varying QROT inside accepted substeps, general root-stress physics, or a complete controlled theory-to-equation trace.

## Restricted parallel root-active execution

`RB1-ROOT-PARALLEL` is the root-active physics composition qualified by F-MQ30 for 2 and 4 workers. The frozen implementation is represented by `mod_fmr_parallel_root_uptake_pool` together with the shared root-process and solver/provider contracts.

F-MQ30 requires exact scientific-result identity between serialized, 2-worker and 4-worker execution by column id; exact committed endpoint-state and continuation identity; deterministic canonical publication; and actual-transpiration attribution equal to the integral of the root extraction sink over the accepted interval. Attribution is explicitly not a second water-mass booking. Per-column hard water-mass residual is bounded at `1e-12 cm` in the qualified matrix.

Its negative matrix is part of the scope boundary: negative or NaN QROT, a root-inactive request, worker count 1 through the explicit parallel-root entry point, unsupported worker counts and excluded physics must fail closed before the requested profile can be silently reinterpreted. Root-active restart, unsupported parallel physics and performance speedup are nonclaims.

This distinction also preserves the architecture rule that numerical execution topology must not silently change physics. A column outside the admitted root-active parallel profile belongs in a different execution path/template rather than being coerced into the qualified one.

## Restricted surface evaporation

`RB1-SURFACE-EVAP-RESTRICTED` is narrower than general SWAP surface evaporation. Its frozen release scope is the stateless `SWINTER=0`, `SWREDU=0` profile. `mod_restricted_surface_evaporation` owns the restricted process calculation; the capacity contract/provider supplies hydraulic capacity without exposing HeadCalc internals to the process; `mod_fmr_surface_evaporation_runtime_materialization` performs the frozen runtime materialization.

F-CI41P records final post-promotion governance reconciliation for the restricted surface-evaporation postimage and binds independent F-VQ56 authority. It explicitly records no production/reference/scientific-oracle delta during that governance reconciliation and states that the existing call-local copy/allocation performance debt remains deferred.

F-PE11 then preserves functional behaviour against the F-CI41P/F-VQ56 oracle. Its gates include observable identity, O0/O2 identity, committed-state immutability, A/B/A determinism and no authoritative mass booking inside the materialization. The explicit final marker is `FPE11_THROUGHPUT_SCALING_CLAIM=NOT_YET_MADE`.

That marker is a hard documentation boundary. F-DOC06 records functional MultiSWAP compatibility only. It does not qualify throughput, scaling, allocation efficiency or whole-model speedup. In particular, the known call-local copy/allocation topic remains a separate performance workunit and this documentation workunit does not reopen the closed scientific/canonical admission.

## Mass and ownership semantics

For the ET/root chain, actual transpiration is attribution of the already represented root extraction sink and must not create a duplicate water withdrawal. For restricted surface evaporation, the materialization/evaluator does not create a second authoritative top-water mass booking; accepted solver/external top-flux accounting remains authoritative in the frozen release composition.

These are not optional performance concessions. The F-DOC06 trace preserves the RB1 hard mass-conservation requirement and introduces no new tolerance or alternate mass-accounting path.

## Traceability tiers

For all three capabilities F-DOC06 resolves or binds only what the repository supports directly:

- T8 algorithm: bounded released process/composition algorithms;
- T9 software contract: frozen ET/root, parallel-root and surface-evaporation interfaces;
- T10 implementation mapping: exact frozen source files and blobs;
- T11 verification: scoped qualification evidence is bound, but a complete equation-to-test graph is not claimed;
- T13 qualification/applicability: immutable RB1 qualification authority;
- T14 release authority: immutable RB1 release authority.

T0 through T7 remain explicitly open in this bounded workunit where no complete controlled theory/model/numerical chain has been established. F-DOC06 does not invent a T1 Feddes, ET or surface-evaporation theory authority merely because those concepts are present in production code or qualification text. T12 also remains open: release qualification is not application validation.

## Architecture consequences

The frozen composition is consistent with the canonical architecture invariants. ET and root uptake remain separate process/runtime contracts rather than hidden global ownership. Root-active parallel execution is a bounded runtime composition over the same scientific process path, not a different physical model. Surface evaporation consumes a clean hydraulic capacity/view interface rather than depending directly on HeadCalc internals. No persistent state is added by the restricted stateless surface-evaporation profile. Worker execution remains a runtime concern, and mass accounting remains single-authority and accepted-state based.

F-DOC06 adds no calendar-day assumption, file-I/O dependency, MODFLOW dependency, deep-vadose assumption or alternative soil-water-solver restriction. It does not change the coupler/runtime composition boundary.

## Explicit nonclaims and remaining gaps

F-DOC06 does not claim `FULLY_TRACED` for any of these capabilities. It does not claim Status A readiness, Status A compliance or Status AA compliance. It does not claim T12 application validation.

It does not broaden the released drought-only precomputed-QROT profile, root-active worker counts, surface interception/reduction physics, root-active restart scope or performance scope. It makes no universal throughput or speedup claim.

The remaining bounded gaps are explicit: T0-T7 theory/conceptual/formal/numerical traceability where a controlled binding still needs to be established, complete T11 equation-to-test graphs, and T12 application validation. Those gaps do not invalidate the frozen RB1 release qualification. They bound the maturity of the documentation traceability claim.
