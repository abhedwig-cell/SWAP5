# F-DOC05 - RB1 Execution and Restart Traceability

## Scope

F-DOC05 populates bounded traceability for exactly five frozen `SWAP5-RB1-v1` capabilities:

1. `RB1-STANDALONE-N1`;
2. `RB1-MULTISWAP-SERIAL`;
3. `RB1-MULTISWAP-PARALLEL-V1`;
4. `RB1-RESTART-SERIAL`;
5. `RB1-RESTART-PARALLEL`.

The exact upstream documentation authority is `F-DOC04@a703747ce1991c5601b76a84f04969b602298268`. The frozen RB1 scientific source remains `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`; RB1 qualification and release metadata remain `aeb74560d801c4ac7314df7b8845fcc5daf8bba6` and `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0` respectively.

F-DOC05 is documentation and traceability only. It does not change production source, reference data, physics, solvers, scientific tolerances, acceptance thresholds, performance policy or the fixed 15-capability RB1 denominator.

## Shared execution route

Standalone N=1 is not a separate SWAP kernel. It is cardinality one on the same serialized runtime used for serial MultiSWAP. The frozen source entry point is `fmr_run_serialized_physical_multiswap` in `src/runtime/mod_fmr_serialized_multiswap_runtime.f90`, blob `f06a2eef7b47880e449cf9b201342d7bd1e197e1`.

This is important for the one-kernel invariant: standalone and MultiSWAP differ in runtime composition and cardinality, not in scientific-kernel identity. F-MQ27 independently exercised column counts `1, 2, 7, 8, 17, 31, 32`, including N=1, over a generic time window without a required calendar boundary. Its qualification also required deterministic replay, endpoint committed-state identity and hard mass residual `<= 1e-12 cm`.

## Restricted parallel V1

The frozen parallel V1 path uses `mod_fmr_parallel_physical_scheduler` and `mod_fmr_parallel_worker_pool`. Multiworker admission is explicitly restricted to 2 and 4 workers in RB1. The generic worker-pool entry point delegates `worker_count == 1` to the same serialized runtime; that delegation is not a parallel-performance claim.

F-MQ30 supplies independent qualification evidence for the admitted 2 and 4 workers, deterministic canonical result publication, exact O0/O2 output identity, worker-owned heavy runtime/solver scratch and hard mass closure. F-DOC05 uses only those execution-topology and runtime properties. The root-process scientific content exercised by F-MQ30 is not promoted here: root-process science remains outside F-DOC05 and belongs in a separate physics-oriented traceability workunit.

No universal speedup, throughput or performance-superiority claim is made. Unsupported multiworker counts remain outside RB1 admission.

## Committed-boundary restart

The restart contract is serialization-neutral. `fmr_committed_restart_record_t` and `fmr_committed_restart_bundle_t` in `src/runtime/mod_fmr_committed_restart.f90` carry stable runtime identity and the compact committed physical continuation state required to resume a column.

The contract deliberately excludes immutable parameter payload duplication and excludes solver/Newton/Jacobian scratch and worker warm starts. It is not a filesystem format. It does not claim cross-version migration and it does not persist trial state or mid-transaction state.

F-MQ27 qualifies serial committed-boundary continuation with continuous-versus-restarted result identity, endpoint-state identity, lineage/revision/time continuation, deterministic replay, hard mass and a fail-closed negative matrix. Malformed or incompatible restore attempts must leave fresh targets uninitialized, so failed restores cannot partially publish state.

F-MQ29 extends the qualified composition to restricted parallel continuation. It covers serialized, 2-worker and 4-worker restart origins, 2- and 4-worker continuation, and the cross-worker routes `2_to_4` and `4_to_2`. Its hard mass gate is `1e-12 cm`; negative gates include malformed physical state, late provenance failure, wrong state family, non-fresh targets, duplicate/unknown columns, and template/layout/parameter mismatches.

## Traceability tiers

For these five capabilities F-DOC05 resolves or binds only what the repository supports directly:

- T8 algorithm: bounded execution and committed-restart algorithms;
- T9 software contract: frozen runtime/restart interfaces;
- T10 implementation mapping: exact frozen source files and blobs;
- T11 verification: scoped qualification evidence is bound, but a complete equation-to-test graph is not claimed;
- T13 qualification/applicability: immutable RB1 qualification authority;
- T14 release authority: immutable RB1 release authority.

T0 through T7 remain open in this bounded workunit rather than inventing a physical or scientific theory for execution topology or restart mechanics. T12 remains open: F-DOC05 does not turn runtime qualification into application validation.

## Architecture consequences

The trace supports several architecture invariants without creating new scientific claims. N=1 and serial MultiSWAP share one runtime/kernel route. Parallel execution owns worker-local heavy context rather than persistent per-column solver instances. Restart persists committed physical continuation state and stable identities rather than scratch. Time remains generic `[t0,t1]`. Restart and execution qualification preserve hard mass accounting. Failed restore operations remain atomic and fail closed.

None of this changes the runtime/coupler ownership boundary, expands physics options, creates a separate standalone model, or changes numerical policy.

## Explicit nonclaims and remaining gaps

F-DOC05 does not claim `FULLY_TRACED` for any of the five capabilities. It does not invent a T1 scientific authority, does not claim T12 application validation, and does not claim Status A readiness, Status A compliance or Status AA compliance.

It does not qualify ET/root science, root-process physics, or surface-evaporation science. It also does not reopen the separately bounded surface-evaporation throughput/scaling topic.

The remaining bounded gaps are therefore explicit: T0-T7 scientific/conceptual/numerical traceability where such a binding is actually meaningful, complete T11 equation-to-test graphs, and T12 application validation. These gaps do not invalidate the already frozen RB1 release qualification; they bound the maturity of the documentation traceability claim.
