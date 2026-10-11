# F-DOC28 authority matrix — Restart v1 technical reference

## Scope

F-DOC28 is documentation-only. It exposes the already-admitted Restart v1 contract for technical review. It does not change production code, reference code, tests, restart payload semantics, transaction ownership, physics or numerical policy.

The scientific/production denominator remains the frozen Status-A baseline `50346642bd565f79134ea17d5462e544b354998c` with production tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`. F-DOC28 starts from moving canonical `74051e113fcef19e021d69854f3ab99066eb30cb` only as its documentation integration base.

## Authority map

| Technical claim | Primary frozen authority | Supporting qualification/preservation authority | Documentation ceiling |
| --- | --- | --- | --- |
| Persistent authority is committed state, not candidate/trial state | `src/runtime/mod_fmr_checkpoint_orchestrator.f90` blob `0dceaa2d108d5c7e1263e0f424a056a8df585908`; `src/kernel/mod_kernel_committed_persistence.f90` blob `ffd886c3401fc12739a456fe60a8741c12b9848b` | F-KT16 completion authority `37a91f16078badaa675235f1230d225a21c9e010` | Describe committed checkpoint/candidate separation; do not claim trial-state persistence. |
| Kernel persistence carrier is serialization-neutral and contains already-committed continuation state plus provenance | `src/kernel/mod_kernel_committed_persistence.f90` blob `ffd886c3401fc12739a456fe60a8741c12b9848b` | F-KT16 | No filesystem, file format or byte-level serialization standard is implied. |
| Frozen FMR restart bundle/record structure | `src/runtime/mod_fmr_committed_restart.f90` blob `19ea410e0ed48e65b5d73887a8e1dba59c7c4f37` | F-KT16 | May document schema v2, kernel schema v1, parameter-set identity and per-record identity/provenance/physical-state fields exactly as implemented. |
| Immutable parameter payload, forcing, solver/Newton/Jacobian scratch and worker warm starts are not embedded in restart record | `src/runtime/mod_fmr_committed_restart.f90` blob `19ea410e0ed48e65b5d73887a8e1dba59c7c4f37` | F-KT16 hard nonclaims | Do not recast omitted scratch/configuration as lost committed scientific state. External reconstruction/continuity remains separately governed. |
| Restart physical state must match template/backend/optional-state/numerical-continuation topology | `src/runtime/mod_fmr_restart_state_contract.f90` blob `872c28bbc345f40073396cce57e4eb43c71de850` | F-KT16 | Describe only registered frozen state families; unknown backends fail closed. |
| Export requires valid ready committed registry and creates per-column records from kernel committed snapshots | `src/runtime/mod_fmr_committed_restart.f90`; `src/kernel/mod_kernel_committed_persistence.f90` | F-KT16 | Do not imply export of in-flight candidate or scratch state. |
| Restore is fail-closed and atomically publishes only after all records validate | `src/runtime/mod_fmr_committed_restart.f90` blob `19ea410e0ed48e65b5d73887a8e1dba59c7c4f37` | F-KT16 | May describe schema, parameter-set, template, parameter-ref, physical-state and fresh-target checks. No partial target publication claim. |
| Restore cannot overwrite an already initialized authoritative committed carrier | `src/kernel/mod_kernel_committed_persistence.f90` blob `ffd886c3401fc12739a456fe60a8741c12b9848b`; FMR runtime additionally rejects initialized target registries | F-KT16 | Restore is creation/reconstruction of committed authority, not rollback over an existing authoritative state. |
| Restart continuation is regression-protected | F-KT16 `37a91f16078badaa675235f1230d225a21c9e010` | F-TB11 `FTB11-RST-001`; F-VQ65 authority `b1fd9e15a22d4dd68997ec38c074ce343eec0a70`; Status-A `TRACEABILITY.md` | Report bounded qualified/preserved continuation only; historical testbank authority is snapshot-bound and not automatically rebound. |

## Qualification chain

F-KT16 closes State / Persistence / Restart v1 at 100% for the frozen D02 completion denominator:

- closeout: `37a91f16078badaa675235f1230d225a21c9e010`;
- qualified head: `81b2492f947df063742aa5998355d97d721af699`;
- workflow: `.github/workflows/fkt16-state-persistence-restart-v1-final-qualification.yml`;
- gate: `tests/fkt/run_fkt16_state_persistence_restart_completion_gate.sh`;
- run `34746928353`, job `103696445028`, conclusion `success`;
- recorded gates include exact-current-canonical, no-production/reference-delta, independent restart chain, process-state completeness, current-canonical admission preservation, and state-ownership/schema structure.

The permanent-testbank snapshot later adopts F-KT16 as the Restart authority under stable ID `FTB11-RST-001`. Its moving-current replay uses independent verifier evidence, including F-VQ65 preservation where `restart_serialized_multiswap` is recorded PASS. Current Status-A traceability separately records same-tree restart observable and mass-preservation replay for the frozen Status-A production tree.

## Hard nonclaims

F-DOC28 does not claim any of the following:

- mid-transaction trial-state or disposable worker-scratch persistence;
- a filesystem or byte-format standard;
- future-major-schema migration compatibility;
- distributed crash-recovery semantics;
- deep-vadose or broad MODFLOW restart qualification;
- universal restart safety for future state-owning capabilities;
- parallel/concurrent real-physics MultiSWAP restart beyond separately admitted scope;
- any new production functionality, physics, numerical policy or restart semantics.

## Reviewer rule

A future state-owning capability may inherit Restart v1 only after its committed continuation state, template/layout identity, capture/restore ownership and continuation regression dependency are explicitly covered. Presence of a value in process memory is not restart authority.
