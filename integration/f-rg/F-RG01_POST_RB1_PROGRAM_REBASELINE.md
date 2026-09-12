# F-RG01 - SWAP5 Post-RB1 Program Rebaseline, Dependency Graph & Parallel Workstream Authority

Status: `QUALIFIED_POST_RB1_PROGRAM_REBASELINE_AND_PARALLEL_EXECUTION_PLAN_ESTABLISHED`

Scope: central program governance only. This authority changes no production source and reopens neither RB1 nor any already closed scientific/canonical authority.

## 1. Exact restart authority

Immutable release reference:

- RB1 tag: `swap5-rb1-release`
- RB1 release SHA: `b52e68107be36884a30d01b78089c3b8e85e97f8`
- RB1 status: `100%`, immutable and not recalculated here.

Post-RB1 program restart authority at F-RG01 close:

- canonical branch: `integration/f-ci-canonical`
- canonical SHA: `6c04ab07b4535c119157b5c5bce674b626656f07`
- canonical tree: `2a9371508def2ce2f90284f1131cd98a1eaf8472`
- immediate parent: `39b8ed3d33c564530feeeb1e1c6d5af0a0be6636`
- parent meaning: `promote(F-CI50): admit F-GC17 typed groundwater interface`
- head meaning: `F-CI49P: finalize post-reconciliation closeout`
- delta from F-CI50 promotion head to F-RG01 restart head: governance evidence only, `integration/f-ci/F-CI49P_STATUS.json`; no production source delta.

Therefore `6c04ab07...` is the exact F-RG01 restart authority. Older canonical heads remain historical provenance, not valid new-work restart heads.

Open moving-preservation note:

- `qualification/f-ci50p-current-canonical-postimage-reconciliation` exists.
- observed head: `4654a23bcda5a0065cdc18f06bfd30ccb5b944a9`.
- no workflow run was present at F-RG01 snapshot time.
- F-CI50P is therefore an open serial preservation gate and not part of this restart authority.

## 2. Governance rules established by F-RG01

1. At most one active production owner may exist for one semantic capability.
2. Canonical admission is serial. Two F-CI promotions may not race.
3. A downstream production branch must start from, or explicitly recompose onto, the newest required admitted dependency. A stale canonical may not be used when the branch requires a newer pending or admitted authority.
4. `source owner -> independent qualification -> F-CI admission -> postimage preservation` is the production authority chain. Presence of a file or status document on canonical is not by itself admission evidence.
5. Owner-side CI is not independent qualification.
6. Production file overlap is not the only conflict. Semantic ownership, shared contracts, ancestry and qualification dependencies can require serialization even when files differ.
7. Hard mass conservation remains non-delegable. No performance, fallback, coupling or reduced-order work may trade it away.
8. Solver policy may not silently change physics. Alternative solvers remain behind the common soil-water interface.
9. RossFast and other alternative fast solvers are `OPTIONAL_STRETCH_CAPABILITY` and carry zero weight in SWAP5-v1 completion.
10. The completion metric below is fixed-denominator. A production gate receives credit only when current-canonical admitted. A non-production gate receives credit only at qualified closeout. Partial branches receive no fractional credit.

## 3. F-CI authority chain since the qualified baseline exit

The qualified canonical-development-baseline exit is F-CI18:

- F-CI18 closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualification states the complete F-CI03 through F-CI18 dependency chain passed.

Live post-F-CI18 authority families observed at F-RG01:

- integration/candidate: F-CI19 candidate preservation/convergence, F-CI20 post-FCI19 convergence, F-CI21 temporal-certificate materialization.
- F-CI22 temporal certificate canonical admission.
- F-CI23 canonical provenance gate reconciliation.
- F-CI24 F-PM06A reference ET canonical admission.
- F-CI25 MultiSWAP runtime admission readiness.
- F-CI26 F-MR21 restart canonical requalification.
- F-CI27 F-MR23 reference ET runtime canonical admission.
- F-CI28 F-MR25 restart canonical admission.
- F-CI29 F-MR26 ptra ownership canonical admission.
- F-CI30 F-MR27 parallel-v1 canonical admission, plus source-compose checkpoint.
- F-CI31 F-MR28 reference ET/root-uptake recomposition and execution admission.
- F-CI32 F-PM08BR DIVDRA canonical admission.
- F-CI33 F-MR33 DIVDRA runtime canonical admission; F-CI33R postimage reconciliation.
- F-CI34 root-attribution admission/recomposition plus F-CI34G/F-CI34P postimage governance.
- F-CI35 parallel committed restart current-canonical admission.
- F-CI36 F-MR36 DIVDRA active-runtime canonical admission.
- F-CI37 F-MR35 parallel root-uptake canonical admission; F-CI37P postimage governance reconciliation.
- F-CI38 historical admission-gate scope separation.
- F-CI39 F-PM06E surface-evaporation capacity canonical admission; F-CI39P postimage governance.
- F-CI40 F-MR38 effective-forcing executor canonical admission.
- F-CI41 F-PM06F surface-evaporation runtime canonical admission; F-CI41P postimage governance.
- F-CI42 F-PE11 surface-evaporation allocation canonical admission; F-CI42P postimage governance.
- F-CI43 F-PM07B restricted soil-temperature canonical admission; F-CI43P postimage governance.
- F-CI44 F-GC10 application-accuracy contract canonical admission; F-CI44P reconciliation.
- F-CI45 F-MR39 soil-temperature runtime canonical admission plus donor snapshot; F-CI45P reconciliation variants.
- F-CI46 F-GC14 external-accuracy runtime adapter canonical admission; F-CI46P reconciliation.
- F-CI47 moving-preservation-authority reconciliation; F-CI47R accidental support-file remediation record.
- F-CI48 F-MR41 typed optional-state-layout canonical admission; F-CI48P reconciliation.
- F-CI49 definitive F-KT15 Task2 solver-service transaction composition canonical admission; F-CI49P reconciliation and final closeout.
- F-CI50 F-GC17 typed groundwater-interface canonical admission.
- F-CI50P current-canonical postimage reconciliation: open at this snapshot.

`integration/f-ci-canonical-copy`, temporary compose branches, old working branches and historical candidate branches are not restart authorities.

## 4. Current dependency DAG

```text
RB1 immutable release
  |
  v
F-CI18 qualified canonical-development-baseline exit
  |
  +--> temporal/provenance admissions F-CI22..23
  |
  +--> ET/root-uptake/process admissions F-CI24,27,29,31,34,37,39,41
  |       |
  |       +--> F-WOF43A canopy-view provider -> F-VQ37 -> [pending canonical admission]
  |
  +--> MultiSWAP/restart/runtime admissions F-CI25,26,28,30,33,35,36,40,45,48
  |       |
  |       +--> F-MR41 typed optional state layout [CURRENT_CANONICAL]
  |       +--> F-PM08D7 fixed-weir transactional runtime [owner qualified -> independent FVQ required]
  |
  +--> solver/interface line
  |       F-SI30 dynamic top boundary
  |          -> F-KT15 definitive solver-service transaction composition
  |          -> F-CI49 -> F-CI49P [CURRENT_CANONICAL]
  |          -> RossFast research [optional, zero v1 weight]
  |
  +--> coupling line
          F-GC10 application accuracy -> F-CI44
          F-GC14 external accuracy adapter -> F-CI46
          F-GC16 minimum production composition plan
          F-GC17 typed direct-GW interface -> F-CI50 [CURRENT_CANONICAL]
             |
             +--> F-CI50P preservation [OPEN SERIAL GATE]
             +--> F-GC18/F-GC19 production coupling runtime work
                    -> F-GC20/F-GC21 composition/qualification
                    -> F-GC22 downstream restricted production profile

Cross-cutting evidence:
  F-TB01..08 qualified -> F-TB09 integrated process-interaction catalog
  F-DOC01..13 qualified -> F-DOC15 Status-A gap authority -> F-DOC16/F-DOC17 and validation/toolchain backlog
```

## 5. Ownership and current-authority matrix

| Capability | Production owner / workunit | Definitive source authority | Independent qualification | Canonical admission / preservation | Successor or blocker | Production files / boundary | Class |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RB1 release baseline | none, immutable | `swap5-rb1-release@b52e681...` | release-qualified | immutable | none | whole RB1 release image | CURRENT_CANONICAL |
| Canonical baseline governance | F-CI | F-CI18 close `7f906fc...` plus current F-CI chain | canonical CI chain | current head `6c04ab0...` | F-CI50P | integration/admission evidence, not capability ownership | CURRENT_CANONICAL |
| Dynamic top-boundary solver interface | F-SI30 | `work/f-si30-dynamic-top-boundary-solver-interface@27b10ac...` | closed qualified | preserved through KT15/F-CI49 composition | no competing owner allowed | solver contract, reference binding, legacy bridge and top-boundary provider boundary | CURRENT_CANONICAL |
| Soil-water solver-service transaction composition | F-KT15 Task2 only | `work/f-kt15-task2-solver-service-production-composition`; reconciliation `a67897f...` | reconciled gate qualified | F-CI49 plus F-CI49P | any new solver-service production work must serialize | semantic ownership of solver-service transaction composition, not blanket ownership of all solver files | CURRENT_CANONICAL |
| Parallel root uptake | F-MR35 | admitted F-MR35 source | F-MQ30 `48ee284...` | F-CI37/F-CI37P | preserve only | runtime/root-uptake composition | CURRENT_CANONICAL |
| Typed optional state layout and serialized runtime state | F-MR41 | `work/f-mr41-typed-optional-state-layout-contract@e7165e5...` | closed qualified | F-CI48/F-CI48P | future runtime work must retain compact optional state | `src/runtime/mod_fmr_runtime_core.f90`, `mod_fmr_serialized_reference_backend.f90`, `mod_fmr_restart_state_contract.f90` | CURRENT_CANONICAL |
| Surface evaporation allocation scaling | F-PE11 | `performance/f-pe11-surface-evaporation-allocation-scaling@b436f8e...` | qualified performance evidence | F-CI42/F-CI42P | separate performance work only | performance evidence/support, no broad process ownership | CURRENT_CANONICAL |
| Typed direct groundwater interface and convergence policy | F-GC17 | `work/f-gc17-typed-direct-groundwater-interface-convergence-policy@f0e9465...` | owner close qualified and F-CI50 admission gate | F-CI50 at `39b8ed3...`, preserved in current ancestry | F-CI50P, then F-GC18/19 | `src/runtime/mod_groundwater_coupling_contract.f90`, `src/runtime/mod_groundwater_coupling_policy.f90` | CURRENT_CANONICAL |
| Production groundwater coupling composition plan | F-GC16 | `work/f-gc16-production-groundwater-coupling-minimal-viable-composition-admission-plan@5e2e77c...` | qualified plan | not a production admission | F-GC18..22 | documentation/governance only | DOCUMENTATION_ONLY |
| Crop-to-ET canopy view provider | F-WOF43A | `work/f-wof43a-crop-et-canopy-view-provider@df72af4...` | F-VQ37 `3dc40ec...` | none yet | replay/rebase to restart authority, then proposed F-CI admission | `src/crop/mod_crop_et_canopy_view_provider.f90` | QUALIFIED_PENDING_ADMISSION |
| Restricted fixed-weir transactional runtime | F-PM08D7 | `work/f-pm08d7-restricted-fixed-weir-transactional-runtime-candidate@de90d3b...` | owner-side exact-head gate only | none | repin/replay, independent FVQ, then F-CI | surface-water/fixed-weir runtime boundary | OWNER_QUALIFIED_PENDING_FVQ |
| Integrated column physics interaction catalog | F-TB09 | `work/f-tb09-integrated-column-physics-process-interaction-catalog@759d780...` | not yet current-canonical reconciled | not production | repin to newest canonical and close TB09 | testbank only | TESTBANK_ONLY |
| Status-A readiness/gap authority | F-DOC15 | `work/f-doc15-rb1-current-canonical-status-a-final-gap-assessment@81af9e5...` | exact-head workflow PASS | pinned to earlier F-CI49 snapshot, not current F-CI50 postimage | current-only documentation reconciliation | documentation only | DOCUMENTATION_ONLY |
| Physical system 1D conceptual authority | F-DOC16 | active `work/f-doc16-physical-system-1d-column-conceptual-authority` | latest observed exact-head workflow not qualified | n/a | repair/qualify DOC16 | documentation only | BLOCKED |
| RossFast / fast MFP feasibility | F-ROSS01 | `work/f-ross01-fast-mfp-feasibility@3a78d4f...` | research evidence only | none | may continue only behind stable solver contracts | experimental solver research, no production ownership | RESEARCH |

Family census interpretation:

- F-KT: KT15 Task2 is definitive current solver-service production owner. Competing KT15 recomposition/production branches are superseded.
- F-SI: F-SI30 is the latest closed dynamic top-boundary interface authority used by the admitted solver composition.
- F-PM: PM06/07 admitted process capabilities remain preserved; PM08D7 is the open fixed-weir production candidate and is not independently qualified.
- F-MR: current admitted runtime chain reaches MR41. `work/f-mr21-do-not-use` and obsolete recomposition variants are non-authoritative.
- F-MQ: independent qualification family; F-MQ30 is the verified parallel-root-uptake qualification anchor.
- F-VQ: independent physics qualification family. F-VQ37 qualifies WOF43A. F-VQ57 concerns F-PM06G surface evaporation and is not a KT15 authority.
- F-GC: GC10, GC14 and GC17 are admitted capabilities; GC16 is a composition plan; GC18+ remain future production coupling work.
- F-TB: TB01..08 are qualified preconditions; TB09 is the active integrated interaction bank.
- F-DOC: DOC01..13 are qualified authority chain; DOC14 is not an independent qualified authority; DOC15 is the qualified readiness assessment; DOC16 is active but blocked at qualification.
- F-PE: PE11 is admitted performance evidence; new performance work does not own process physics.
- F-WOF: WOF43A is independently qualified but still pending canonical admission.

## 6. Superseded, stale and non-authoritative branches

The following may remain useful as provenance but must not be used as new restart/production authorities:

- canonical heads `e537baf...` F-CI48P, `42544af...` F-CI49 and `ca1dbf6...` F-CI49P are historical ancestry, not current restart heads.
- competing KT15 branches `work/f-kt15-production-soil-water-solver-service-transaction-composition`, `work/f-kt15r-current-canonical-transaction-composition`, `work/f-kt15r-production-solver-service-current-canonical-recomposition`: SUPERSEDED by reconciled Task2 ownership.
- `work/f-mr21-do-not-use`: SUPERSEDED.
- `archive/f-pm08d7-preproduction-85e17bb7`: SUPERSEDED.
- `tmp/f-ci42-compose-stage`: SUPERSEDED.
- `integration/f-ci-canonical-copy`: not a restart authority.
- F-DOC14 alias/non-independent line: SUPERSEDED as an authority claim.
- duplicate/non-authoritative F-DOC15 variants must not replace the qualified RB1/current-canonical readiness branch.
- F-RG01 auxiliary empty snapshot/alias branches created while freezing this audit are not authorities; only `regie/f-rg01-post-rb1-program-rebaseline` plus this file is the F-RG01 authority.

## 7. Safe-parallel conflict matrix

`SAFE_PARALLEL` means no known production-file or semantic-owner overlap and no required ancestry dependency. `PARALLEL_AFTER_PINNING` means the work may proceed concurrently only after each branch records the exact prerequisite authority. `SERIAL_REQUIRED` means one line must finish or hand off before the other can safely modify/admit the shared semantic capability.

| Pair | File overlap | Semantic overlap | Shared contract | Ancestry / qualification dependency | Decision |
| --- | --- | --- | --- | --- | --- |
| WOF43A admission prep vs PM08D7 FVQ | none known | no | ET/runtime contracts only | both must pin current canonical | PARALLEL_AFTER_PINNING |
| WOF43A admission prep vs GC18/19 | none known | no | runtime contracts may be shared | both must pin preserved canonical | PARALLEL_AFTER_PINNING |
| WOF43A vs TB09 | none | no | TB09 may consume WOF capability | evidence can lag production | SAFE_PARALLEL |
| WOF43A vs DOC16 | none | no | conceptual terminology only | none | SAFE_PARALLEL |
| PM08D7 FVQ vs GC18/19 | no direct overlap established | possible runtime transaction boundary interaction | runtime transaction contracts | final composition may converge | PARALLEL_AFTER_PINNING; SERIAL_REQUIRED at shared runtime composition |
| PM08D7 vs TB09 | none in production | no owner conflict | TB09 may test it | TB09 must record admitted status honestly | SAFE_PARALLEL |
| PM08D7 vs DOC16 | none | no | documentation may describe boundary | none | SAFE_PARALLEL |
| GC18 vs GC19 | expected adjacent coupling runtime | yes, one coupling-runtime program | yes | GC19 must consume qualified GC18 contracts where specified | SERIAL_REQUIRED unless explicit non-overlapping contracts are frozen first |
| GC18/19 vs TB09 | no production overlap | no | coupling/interface tests | pin GC17/F-CI50 preservation first | PARALLEL_AFTER_PINNING |
| GC18/19 vs DOC16 | none | no | physical-system boundary language | none after terminology pin | SAFE_PARALLEL |
| TB09 vs DOC16 | none | no | shared conceptual vocabulary only | no production dependency | SAFE_PARALLEL |
| RossFast vs any solver-service production edit | likely/possible | yes, soil-water solver path | solver interface/transaction contract | production owner has priority | SERIAL_REQUIRED for shared contract/source; research otherwise PARALLEL_AFTER_PINNING |
| any two F-CI admissions | integration evidence | canonical ownership | canonical gate | one moving canonical head | SERIAL_REQUIRED |
| F-CI admission vs its required postimage preservation | integration evidence | same admission lineage | preservation contract | postimage follows promotion | SERIAL_REQUIRED |

## 8. Canonical admission queue at F-RG01 close

1. `F-CI50P` current-canonical postimage reconciliation. Existing branch, open, no workflow run observed. This is the immediate serial gate.
2. F-WOF43A canopy-view provider. Independently qualified by F-VQ37, but first replay/recompose against the exact post-F-CI50P restart authority. Proposed next F-CI admission only after that replay is clean.
3. F-PM08D7 restricted fixed-weir runtime. Not admission-ready. It first requires a fresh canonical pin and independent FVQ. Only then may an F-CI admission be opened.
4. Future F-GC18/19 production coupling capabilities. They must not enter admission until the F-CI50P preservation base is closed and their own owner/qualification chain is complete.

Documentation and testbank work do not enter the production admission queue merely because they close.

## 9. Top remaining gaps

1. Production groundwater coupling is not yet a runtime, despite the admitted typed interface. Missing are generic-window predictor/corrector execution, rollback/corrector composition, sensitivity consumption, residual orchestration and end-to-end conservation qualification.
2. PM08D7 fixed-weir/surface-water transactional runtime lacks independent qualification and is pinned to stale owner-workflow assumptions.
3. WOF43A is independently qualified but not admitted.
4. Integrated process-interaction qualification is incomplete. TB09 must become current-canonical and prove conservation across meaningful process combinations.
5. Bounded-cost solving, fallback qualification and very-large-batch failure isolation remain incomplete as v1 production guarantees.
6. Several physics breadth items remain outside current v1 admission/qualification, notably full irrigation, fixed-weir/surface-water completion, macropore production coverage and integrated mixed-process qualification.
7. F-DOC15 formally says Status-A is NOT_READY. Public crosswalk status at its qualified snapshot is 2 SATISFIED out of 22, with validation, sensitivity, uncertainty, fitness-for-purpose, parameter provenance, user guidance and controlled theory still incomplete.
8. F-DOC16 conceptual 1D physical-system authority is not yet qualified.
9. Exact-current documentation reconciliation lags the moving canonical after F-DOC15's pinned F-CI49 snapshot.
10. Controlled WR-QA-2024 full-text reconciliation remains an external authority dependency. Public Status-A readiness must not be represented as certification.

## 10. Recommended next workunits

Recommended order preserves the serial gates while maximizing safe parallelism:

1. Finish F-CI50P postimage/current-canonical preservation.
2. Proposed F-CI51: WOF43A canonical admission after exact-current replay of the already independently qualified F-VQ37 candidate.
3. PM08D7 independent qualification workunit: repin owner candidate to current canonical, replay, then perform independent FVQ without creating a second surface-water runtime owner.
4. Proposed following F-CI admission for PM08D7 only after independent FVQ passes.
5. Finish F-TB09 against the newest admitted canonical and keep hard water-balance checks explicit in every physically applicable integrated case.
6. Repair and qualify F-DOC16 physical-system/1D-column conceptual authority.
7. Start F-GC18 only from the preserved F-CI50 lineage: restricted generic-window production coupling transaction/predictor runtime.
8. F-GC19: corrector/interface-residual/flux-conservation and response-sensitivity consumption, respecting the F-GC18 contract handoff.
9. Continue the F-GC20/F-GC21 composition and end-to-end qualification sequence only after their stated GC18/GC19 dependencies are satisfied; do not run F-GC21 around them.
10. Start the DOC15 backlog lanes F-DOC17/F-VAL01/F-TEC01 and TB10 where their prerequisites are met, prioritizing scientific theory traceability, real validation, parameter provenance and exact-current test/toolchain evidence.

Workunit numbers proposed here for future F-CI admissions are planning identifiers only until actually created. Existing F-GC and DOC/TB identifiers retain the contracts already defined by their own authorities.

## 11. Explicit serial gates

The following are mandatory serialization points:

- F-CI50P must close before downstream work claims an exact preserved post-F-CI50 canonical base.
- only one F-CI admission/promotion may move canonical at a time.
- WOF43A admission must use its definitive F-VQ37-qualified candidate and may not be unioned with unrelated production work.
- PM08D7 must pass independent qualification before any canonical admission.
- any new soil-water solver-service transaction composition must hand off from the admitted KT15 Task2 owner. No parallel competing KT15-style production owner is permitted.
- any new kernel/runtime transaction owner that overlaps F-MR admitted runtime composition must serialize at the shared semantic contract even if files differ.
- coupling runtime production ownership remains one line. GC18/19/20/21/22 must follow their explicit dependency chain rather than spawn competing direct-coupling runtimes.
- production RossFast integration, if ever proposed, is serial behind a separate qualification/admission decision and may not enter via research ancestry.

## 12. Optional research lanes

Allowed without affecting SWAP5-v1 completion, provided they are pinned to stable contracts and do not claim production ownership:

- F-ROSS01 fast MFP/RossFast feasibility and alternative fast soil-water solvers.
- analytical/reduced-order solver research behind the common soil-water interface.
- performance experiments that do not alter admitted physics or hard conservation.
- deep-vadose transfer-zone research outside SWAP, with explicit mass-safe transition contracts.
- vectorization/GPU/batching research behind stable model-template/runtime contracts.

These lanes are `RESEARCH` until separately qualified and admitted. RossFast has zero weight in the v1 denominator.

## 13. Fixed-denominator SWAP5-v1 completion model

This is a program-management metric established by F-RG01, not a claim of scientific validation. Denominators are fixed here so branch proliferation cannot inflate progress.

### Production engine: 10 / 12 = 83.3%

Credited gates: single kernel/data boundary; transaction checkpoint/trial/rollback/commit; generic time contract; reference Richards abstraction/binding; dynamic top boundary plus admitted solver-service composition; sensitivity-result transport; committed-state reconstruction/restart; result/transaction diagnostics; physics-versus-solver-policy separation; corrected legacy/reference oracle route.

Open gates: complete remaining production process transaction composition; bounded-cost/fallback qualification against reference.

### Physics breadth: 8 / 12 = 66.7%

Credited: core soil water/Richards, reference ET demand, root uptake, surface evaporation, drainage/DIVDRA, restricted soil temperature, admitted snow/reference process coverage, core WOFOST/accepted-window crop process coverage.

Open: complete irrigation production path, fixed-weir/surface-water completion, macropore production coverage, integrated mixed-process physics qualification.

The pending WOF43A canopy provider is an incremental capability and does not revoke already qualified core crop coverage.

### MultiSWAP/runtime: 8 / 10 = 80.0%

Credited: indexed column runtime, immutable parameter/registry views, compact committed state/restart, parallel-v1 execution, worker scratch/cache ownership, effective forcing executor, process/root-attribution ownership, typed optional-state layout/serialization.

Open: bounded-cost solver/fallback runtime policy; very-large-batch diagnostics/failure isolation qualification.

### Coupling: 3 / 10 = 30.0%

Credited: application-accuracy contract, external-accuracy runtime adapter, typed direct-groundwater datum/sign/unit/convergence interface.

Open: generic-window predictor/corrector runtime, rollback/corrector coupling transaction, sensitivity consumption, residual/convergence orchestration, MultiSWAP tile-to-groundwater aggregation, optional deep-vadose transfer composition, end-to-end coupled qualification.

### Testbank: 8 / 10 = 80.0%

Credited: qualified F-TB01 through F-TB08 authorities.

Open: F-TB09 integrated process-interaction qualification; a current-canonical integrated executable/end-to-end testbank layer (TB10-class scope).

### Scientific traceability/documentation: 4 / 10 = 40.0%

Credited outcome gates: software/kernel architecture authority; temporal/numerical/restart formal authority; qualification/provenance/status authority through RB1 and post-RB1; qualified Status-A public-gap crosswalk F-DOC15.

Open: qualified physical-system 1D conceptual authority; parameter provenance registry; controlled scientific/physical/hybrid theory guide; user/modeler guidance; sensitivity/uncertainty/fitness-for-purpose corpus; exact-current canonical documentation plus controlled WR-QA-2024 reconciliation.

### Status-A readiness: 2 / 22 = 9.1%

This follows the strict public 22-item crosswalk in qualified F-DOC15: only items marked `SATISFIED` receive credit. F-DOC15 explicitly concludes `NOT_READY`; certification was not performed or claimed. The controlled WR-QA-2024 denominator cannot be substituted until its exact authority is available.

### Overall SWAP5-v1: 41 / 64 = 64.1%

Overall v1 combines the first six fixed-denominator program categories: 12 + 12 + 10 + 10 + 10 + 10 = 64 gates, with 41 credited at F-RG01 close.

Status-A readiness is reported separately and is not added again to the overall denominator because its requirements overlap documentation, test, validation and production-evidence gates. Adding the 22 again would double-count the same deficits.

RB1 remains `100%` immutable and is not part of this post-RB1 percentage calculation. RossFast carries `0` gates and `0` weight.

## 14. Restart and parallel execution decision

New post-F-RG01 work must use this rule:

1. read this authority;
2. recheck `integration/f-ci-canonical` live;
3. if canonical still equals `6c04ab07...`, use it unless an explicitly required serial preservation/admission gate is underway;
4. if canonical moved, identify the admission/preservation delta and re-pin before production work;
5. retain exactly one semantic production owner per capability;
6. independent qualification stays separate from owner qualification;
7. production admission remains serial;
8. documentation, testbank and research may run in parallel where the matrix above permits, but must not silently upgrade their authority class.

Target reached: `QUALIFIED_POST_RB1_PROGRAM_REBASELINE_AND_PARALLEL_EXECUTION_PLAN_ESTABLISHED`.
