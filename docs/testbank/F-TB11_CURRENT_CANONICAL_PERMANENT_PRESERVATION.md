# F-TB11 Current-Canonical 100% Capability Permanent Testbank Preservation

## Scope

F-TB11 preserves already-qualified SWAP5-v1 capabilities against regression. It does not develop or alter production physics, solver algorithms, drainage algorithms, coupling algorithms or crop physics.

The preservation snapshot is bound exactly to:

- `integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- tree `556221f62b4fde616981499eba68ef5460f5d83c`
- source tree `73490c41aee380cda01b88da6ceeb9f6637d2ecf`
- reference tree `9d08625217d7c0a7385df9da6a04183bcd9cb9e6`
- tests tree `bfdbe47c1c76b4109e9daa4f4aff11182bbbbd6f`
- successful canonical qualification run `34781202197`

A later canonical head is not covered by this authority until an explicit rebind and requalification is performed.

## Adopted 100% authorities

| Capability | Qualification authority | Authority tree | Decision |
|---|---|---|---|
| Kernel / Transactions / Generic Time / Mass v1 | `F-KT19@004f8f438ce1380c940a5139df83165c4d2eb68c` | `c48234ef7e0ed4c8bcb2e968c6fce299cb321240` | `QUALIFIED_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_100_PERCENT_COMPLETE` |
| State / Persistence / Restart v1 | `F-KT16@37a91f16078badaa675235f1230d225a21c9e010` | `3ddacee88898872ec4541b721b74cce63117bbed` | `QUALIFIED_STATE_PERSISTENCE_RESTART_V1_100_PERCENT_COMPLETE` |
| Serialized MultiSWAP v1 | `F-MR42@e370f95c2e50c2fef46fe99eac11522046560938` | `c142f51d55338a7f942123534242dd89e03a34e8` | `QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE` |
| Full Richards reference solver v1 | `F-SI33@8a162a7b4aa7a67778ed9be454cfcd67d01276ce` | `df36bf7d42ffdfdd27755733f5f6a1b7c8194083` | `QUALIFIED_FULL_RICHARDS_REFERENCE_SOLVER_V1_100_PERCENT_COMPLETE` |
| Solver Interface / HeadCalc Isolation / Hydraulic Process Boundary v1 | `F-SI35@6d94262ab05b73486257f444b6dfb4b6ec440edf` | `0cacc21318a58ae01c2beecc8f98141f76b0737e` | `QUALIFIED_SOLVER_INTERFACE_HEADCALC_ISOLATION_HYDRAULIC_PROCESS_BOUNDARY_V1_100_PERCENT_COMPLETE` |
| ET / Root Uptake / Surface Evaporation v1 | `F-PM11@602a461957c45623fc414ef15e40a1bfe755de43` | `134e01ef9092277639113d9be64eefc422e4fbb8` | `QUALIFIED_ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_100_PERCENT_COMPLETE` |

F-SI34 is retained as the gap authority only. Final completion credit is taken from the downstream F-SI35 independent-qualification and canonical-admission chain.

Drainage v1 is not credited. At the F-TB11 audit, `work/f-pm13-drainage-v1-completion-audit` still pointed at the canonical start SHA and had no completion result. F-TB10 is also explicitly a blocked authority at `3f7520605452cb07b5bb463fa4fc0f437a5d4598`, with decision `NOT_QUALIFIED_TB09_003_NONSTATIONARY_TEMPORAL_POLICY_GAP`.

## Permanent stable tests

| Stable ID | Principal layer(s) | Oracle and tolerance | Failure semantics |
|---|---|---|---|
| `FTB11-REL-001` | release qualification | exact live canonical SHA/tree/source binding; zero F-TB11 `src/` or `reference/` delta | fail closed on stale canonical or production delta |
| `FTB11-TXN-001` | kernel/transaction, robustness | existing A23BL transaction gate on the exact current source; O0/O2 | transaction regression |
| `FTB11-MASS-001` | kernel/transaction, integrated column, release | exact independent F-VQ65 mass attack matrix; incomplete accounting must reject | hard mass gate failure |
| `FTB11-REJECT-001` | kernel/transaction, process | existing F-MR18 accepted-commit receipt oracle; rejected/prevalidated attempts remain non-mutating; O0/O2 identity | rejected-trial publication mutation |
| `FTB11-RST-001` | persistence/restart, integrated column | F-KT16 authority plus F-VQ65 current-source restart continuation replay | restart exactness/provenance failure |
| `FTB11-MSW-001` | MultiSWAP, performance, integrated column | F-MR42 authority plus F-VQ65 current-source serialized and parallel replay | standalone/MultiSWAP equivalence/provenance failure |
| `FTB11-FR-001` | constitutive, solver, legacy/reference, coupling | F-SI33 100% authority with exact source/reference provenance | Full Richards preservation failure |
| `FTB11-SEAM-001` | solver, kernel/transaction, MultiSWAP | exact F-SI35 blobs, mandatory `soil_water_solver_t` production seam, zero non-admitted direct HeadCalc calls | solver seam or HeadCalc bypass regression |
| `FTB11-ETPUB-001` | process, kernel/transaction, MultiSWAP | exact independent F-VQ71 accepted-publication oracle; stale/cross-lineage paths fail closed; O0/O2 | surface-evaporation publication provenance failure |
| `FTB11-ET-001` | constitutive, process, integrated column, legacy/reference, MultiSWAP, performance | F-PM11 100% authority bound directly to this current canonical and its green qualification run | ET/root-uptake/surface-evaporation preservation failure |

All F-TB01 layers are represented: constitutive, process, solver, kernel/transaction, persistence/restart, integrated column, legacy/reference, coupling, MultiSWAP, performance, robustness and release qualification.

## Horizontal hard gate

Mass conservation is non-waivable. `FTB11-MASS-001` attacks incomplete external ledgers and incomplete certificates and requires fail-closed behavior. No performance, fallback or admission path can turn incomplete mass accounting into an accepted interval.

## Preservation model and duplicate avoidance

F-TB11 deliberately separates immutable authority preservation from moving current-source replay.

Existing F-KT16, F-KT19, F-MR42, F-SI33, F-SI35 and F-PM11 qualification suites are not copied. Historical F-CI admission scripts remain frozen evidence at their qualified postimages. Independent verifier source from F-VQ65 and F-VQ71 is materialized from exact immutable commits only while the F-TB11 runner executes against the exact canonical worktree.

The executable current-source replay covers the highest recent regression risks: fail-closed mass completeness, transaction reject immutability, restart and Serialized MultiSWAP continuation, parallel preservation, coupling preservation, and accepted surface-evaporation publication provenance. Source locks separately prevent reintroduction of a HeadCalc production bypass and loss of the mandatory solver seam.

## Known gap

Drainage v1 is not part of this 100% preservation set until a definitive qualified completion authority exists. This is a testbank coverage boundary, not a scope reduction of drainage itself.

## Exit rule

F-TB11 may close as `QUALIFIED_CURRENT_CANONICAL_100_PERCENT_CAPABILITY_PERMANENT_TESTBANK_PRESERVATION` only if the dedicated workflow is green on the exact branch head containing the manifest, validator, semantic runner, documentation and workflow, while the live canonical remains the recorded SHA/tree and the F-TB11 delta contains no production or reference source changes.
