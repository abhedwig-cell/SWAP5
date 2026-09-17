# F-DOC29 — Serialized MultiSWAP v1 authority matrix

F-DOC29 is documentation-only. It explains the frozen Status-A Serialized MultiSWAP v1 capability without changing production code, the scientific denominator, transaction semantics, restart semantics or execution policy.

## Frozen review denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

## Source owners on the frozen production baseline

| Surface | Frozen blob | Documentation use |
| --- | --- | --- |
| `src/runtime/mod_fmr_serialized_multiswap_runtime.f90` | `1aa2454048d0e480becaee34f596f20f1a7bd66e` | Multi-column registry preflight, deterministic serialized dispatch, per-column transaction/commit, batch and aggregate diagnostics. |
| `src/runtime/mod_fmr_runtime_core.f90` | `43eef1979e0202f8ecc92f73eb7d8025dab515a4` | Logical column/template identities, backend/execution metadata, deterministic `(template_id,column_id)` ordering and generic aggregate diagnostics. |
| `src/runtime/mod_fmr_serialized_reference_backend.f90` | `9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13` | Qualified per-column real-physics backend and worker/backend-local numerical workspace. |
| `src/runtime/mod_fmr_restart_state_contract.f90` | `872c28bbc345f40073396cce57e4eb43c71de850` | Typed physical-state compatibility at committed-boundary restart. |
| `src/kernel/mod_kernel_committed_persistence.f90` | `ffd886c3401fc12739a456fe60a8741c12b9848b` | Committed continuation-state persistence dependency; not arbitrary runtime-memory serialization. |

The first row is the actual multi-column orchestration owner. The per-column serialized reference backend must not be described as if it alone implements MultiSWAP.

## Qualification and admission authority

F-MR42 is the completion authority. Its final closeout is `e370f95c2e50c2fef46fe99eac11522046560938` with decision `QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE`. The final qualification validated head `9e4ae6b872f3aafe51c9312979e7ed88c877ff3d`; workflow run `34746257468`, job `103694630332`, concluded `success`.

F-MR42 records the supporting chain rather than treating its own audit as new independent science:

- serialized real-physics foundation: F-MR05 / independent F-VQ15 at `65efc66cc76fa9005eac46e5779439c5ada574d1`;
- committed restart owner: F-MR19 at `110440d28ff2b585763ad8fd4eedb88e7d112eeb`;
- independent restart qualification: F-MQ29 at `5ea88d81a63e6c706c87e99ac360f91f08711fc1`;
- restart canonical admission: F-CI35;
- typed optional-state owner: F-MR41 at `e7165e598b035282a2cb7527b2fb2f466f1dbbff`;
- typed optional-state current-postimage reconciliation: F-CI48P at `c855d1a012efcd7adda2927e7efe250be5971550`;
- transaction composition postimage: F-CI49P at `938388169d3bb34a3ff9f749c37ff75da05714a6`.

The later Status-A release-readiness authority incorporates Serialized MultiSWAP v1 into the frozen denominator; it does not create new MultiSWAP semantics.

## Preservation authority

Historical permanent-testbank authority F-TB11, commit `74bef08dedb060417d549c8d8cf0fedb8b73e997`, registers stable test identity `FTB11-MSW-001` and explicitly adopts Serialized MultiSWAP v1 via F-MR42. That snapshot remains immutable evidence for its own source binding.

For the frozen Status-A production tree, `docs/status-a/TRACEABILITY.md` records same-tree F-GC29 replay of the Serialized MultiSWAP observable and aggregate-mass preservation, together with relevant retained permanent/mixed-smoke suites. Do not silently rebind the older F-TB11 snapshot to a later head.

## Exact claim ceiling

F-DOC29 may state that the frozen v1 runtime:

1. represents logical columns separately from templates, immutable parameter/forcing registries and mutable committed-state handles;
2. validates the complete registry structure before beginning the serialized physical loop, including unique state ownership;
3. builds a deterministic dispatch order by `template_id`, then `column_id`;
4. executes qualified real-physics columns one at a time through the existing transaction lifecycle;
5. commits or rejects each column through the existing kernel/FMR commit boundary and does not make rejected candidate state authoritative;
6. collects per-column and aggregate diagnostics, including aggregate unrounded mass residual;
7. keeps solver/Newton/Jacobian workspace out of persistent per-column continuation state;
8. supports admitted committed-boundary restart and typed optional persistent state through separately qualified dependencies.

F-DOC29 must not infer whole-batch atomic rollback from the serialized loop merely because registry validation is batch-preflight. The frozen orchestrator commits columns individually as their qualified transaction completes. Any stronger whole-batch publication/rollback claim requires its own authority.

## Explicit nonclaims

F-DOC29 does not claim:

- parallel or concurrent real-physics MultiSWAP;
- arbitrary thread/process safety;
- worker scaling, SIMD/GPU, 100k-column throughput or a general speedup;
- mixed Reference/RossFast MultiSWAP or any RossFast admission inside the frozen denominator;
- broad direct-groundwater/MODFLOW MultiSWAP semantics beyond separately admitted coupling authorities;
- automatic future-process MultiSWAP safety;
- filesystem/byte-format restart interchange, cross-version migration or mid-transaction restart;
- persistence of solver/Newton/Jacobian scratch;
- new physics, solver policy, tolerances or mass policy.
