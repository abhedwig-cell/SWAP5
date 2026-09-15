# Post-F-GC28 residual capability audit

Date: 2026-09-16
Repository: `abhedwig-cell/SWAP5`
Canonical: `integration/f-ci-canonical`
Audit-only workunit. No production source is modified.

## Audit boundary and pinned state

The audit started from the exact post-F-GC28 canonical closeout at `3baf2aa135e3bf257942d9e6c5928990c2d1b2e1` (`close(F-GC28): record groundwater coupling v1 completion audit`). During discovery canonical advanced through unrelated admitted work. The final canonical head observed and used for this persisted audit is `bf0fb81daf0f0fee53566a426886eaa0d0ad2832` (`close(F-CI89): record canonical WOFOST81 runtime activation admission`).

F-GC28 and Groundwater Coupling v1 are boundary conditions for this audit and are not reopened. EB, ROSS and RossFast are excluded.

Classification vocabulary:

- A: CANONICALLY_CLOSED
- B: IMPLEMENTED_AWAITING_INDEPENDENT_QUALIFICATION
- C: QUALIFIED_AWAITING_CURRENT_CANONICAL_ADMISSION
- D: REAL_IMPLEMENTATION_GAP
- E: STALE_OR_SUPERSEDED
- F: FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER

## Residual capability classification

| Candidate capability | Class | Audit basis |
|---|---|---|
| Groundwater Coupling v1 through F-GC28 | A | Canonical audit baseline is the F-GC28 closure. Explicitly not reopened here. |
| Snow restricted one-call daily migration and production admission | C | The Snow production blob is already present unchanged in canonical and F-VQ16 remains reusable. Current-canonical runtime/composition preservation has been rerun on `integration/f-pm02-snow-current-canonical-closure`, but that evidence-only closure branch is not yet canonical. |
| Old Snow integration lineage `integration/f-mr06-snow` as an admission vehicle | E | Historical qualified evidence remains useful, but the old integration lineage is deeply diverged and must not be merged as-is. The current closure branch supersedes it as the admission path. |
| Execution/performance policy for already admitted reference and serialized execution | A | The execution contracts needed by current canonical paths are present and repeatedly exercised by admission/preservation workflows. No residual policy implementation gap was found outside excluded ROSS/RossFast work. |
| F-PE11 surface-evaporation call-local allocation and scaling, current-head preservation | C | F-CI42/F-CI42P already admitted F-PE11 historically. The exact production binding remains qualified, but `mod_kernel_transactions.f90` moved later. The owner checkpoint requires only a narrow current-head preservation replay and no duplicate semantic admission. |
| F-PE07 bounded parallel-v1 scaling characterization | F | Qualified characterization exists, but it is measurement evidence, not an unadmitted production capability. No current release blocker follows merely from this branch. |
| State persistence and Restart v1 | A | F-KT16 completion authority closes Restart v1 at 100 percent; later canonical work also contains parallel committed restart and coupled-restart admissions. No separate residual restart implementation gap was found. |
| Serialized MultiSWAP v1 | A | F-MR42 completion authority closes the serialized MultiSWAP v1 scope. Permanent preservation infrastructure exists. |
| Restricted MultiSWAP restart already covered by admitted persistence/runtime contracts | A | Existing restart and serialized runtime authorities cover the admitted restricted functionality; no distinct current implementation gap was found. |
| Parallel/concurrent real-physics MultiSWAP beyond admitted serialized functionality | F | This is broader execution scope. No evidence establishes it as a current blocker, and it must not be inferred as missing solely because experimental/performance branches exist. |
| Internal transactional orchestration used by canonical runtime | A | Canonical contains the transaction/runtime/adapter layers consumed by later admitted capabilities, including accepted-trajectory and external gateway composition. No residual internal orchestration gap was identified. |
| General stable public/external SWAP5 orchestration API beyond admitted adapters | F | A broad public API contract is not established as a current release prerequisite. Existing adapter work must not be generalized into an invented API requirement. |
| Legacy IO isolation as a complete de-legacy migration | F | Canonical deliberately still contains `src/legacy` beside adapter/runtime/process layers. No current authority makes complete legacy-IO removal a prerequisite. Old IO ideas therefore do not constitute a present implementation gap. |
| Existing IO/adapter boundaries used by admitted capabilities | A | Current source architecture separates adapter, runtime, process, transaction and legacy areas. Admitted capabilities consume these boundaries without requiring a wholesale IO rewrite. |
| Drainage process migration/runtime admission | A | Drainage was admitted and subsequently adopted into permanent preservation by F-TB12/F-TB12P. |
| WOFOST81 preservation and runtime activation through F-CI89 | A | Final observed canonical head closes F-CI89 runtime activation. |
| Remaining non-EB/non-ROSS process migrations not tied to an explicit current acceptance criterion | F | No additional concrete current blocker was found. Historical branches alone are insufficient evidence of an open capability. |
| Generic repository-wide scientific/numerical requalification | F | Qualification remains capability-scoped. No evidence supports reopening all science/numerics globally. The material residual scientific gate is Snow's current runtime/composition preservation only. |
| Permanent testbank preservation machinery | A | F-TB11 establishes permanent preservation for its protected closed set; F-TB12 adds drainage and F-TB12P reconciles its postimage. |
| RB1/RB2 restricted production baseline authority in its historical scope | A | The historical release baseline is closed for its declared scope. |
| New release qualification snapshot for the moving post-RB2 canonical | F | Canonical has advanced substantially since RB1/RB2, but no release cut was requested or established as a current blocking capability. Create a new release authority only when a release boundary is intentionally declared. |
| Historical RB1 Status-A documentation used as current canonical truth | E | F-DOC17/F-DOC18 era authorities predate hundreds of later canonical commits. They remain valid historical evidence, not a live global status source. |
| Current global theory/documentation/code/evidence rollup | F | A fresh global rollup would be useful at a deliberate release/status boundary, but its absence does not imply missing production semantics. Keep capability-local evidence authoritative meanwhile. |
| Early central architecture/status snapshots contradicted by later admission evidence | E | Older snapshots still describe later-closed transaction/coupling capabilities as target/partial. They must not drive current residual-gap decisions. |

No candidate is classified B or D. In particular, the audit found no justified new production implementation gap in the in-scope post-F-GC28 residual surface.

## Open class-C detail

### Snow restricted one-call daily

Owner/closure branch and head: `integration/f-pm02-snow-current-canonical-closure` at `25d83778dcade34225b4630059fd43142f95193d`.

Immutable authorities retained by the current reconcile checkpoint:

- F-PM02 close head `89a834f56317b516acca33b73ab94238ae30204d`
- qualified Snow source commit `2becebfe747663ea3b896d7d19f4381c32df77db`
- exact qualified Snow process blob `54702d71b4c84dce2842813549bd14c57301a383`
- F-VQ16 independent scientific closeout `98712959d811c788c77842eede4c6f558cca1c11`
- F-VQ17 historical runtime closeout `1d9ff946f45488557d10700f047089d3298a4794`
- F-MQ24 historical serialized MultiSWAP closeout `1938d95ab8a4bdf283b13c7efbdf1b6c659af69f`
- historical F-MR06 candidate `ffab7d705928170db3e76a5d346caafeb560e605`

Dependency finding: Snow science did not move. The serialized reference backend and serialized MultiSWAP runtime did move, so only runtime/composition preservation needed refreshing. F-VQ16 remains reusable unchanged.

Minimum next gate: reconcile the small state delta from the branch's pinned GC28 canonical base to the final observed canonical head, confirm F-CI84/F-CI89 WOFOST work does not alter the Snow runtime dependency surface, then admit the evidence-only Snow closure to current canonical. Do not reopen Snow science and do not merge the old F-MR06 lineage.

Parallelism: may run in parallel with F-PE11 because the intended next Snow step is evidence/admission only and its scientific owner is the Snow process/runtime composition, while F-PE11 owns the surface-evaporation allocation/performance seam. Serialize only if either flow unexpectedly needs to mutate a shared runtime/kernel source.

### F-PE11 surface-evaporation allocation/scaling preservation

Owner branch and head: `performance/f-pe11-surface-evaporation-allocation-scaling` at `ac967e3f0f5144f905aac65f2ea9c4c996f2e9a7`.

Qualified postimage/evidence retained by the owner checkpoint:

- qualified head `a0b810bf68d5b5228da5f39ce9e30fc41ddd6954`
- production binding blob `67b346251ba21be62c6ed3077f2c71ddd2c8dd02`
- qualified materialization blob `bc40bc6b121f56071d2b811195759f86130defeb`
- closeout head `b436f8e70664cdb851f20f148463459358568579`
- F-CI42 performance admission retained
- F-CI42P post-promotion governance retained
- F-CI59P materialization postimage/permanent-preservation evidence retained
- owner O0/O2 identity, committed-state immutability, A-B-A determinism, scientific identity and mass nonchange retained

Dependency finding: `src/kernel/mod_kernel_transactions.f90` changed after the prior materialization postimage, but the F-PE11 production binding is unchanged and the surface-evaporation equations did not change. The checkpoint explicitly says duplicate semantic admission is not required if a narrow preservation replay passes.

Minimum next gate: compose against the final observed live canonical without production edits, run the existing narrow F-PE11 functional preservation plus paired local timing workflow, then record current-head preservation/admission closure. Do not make whole-model or MultiSWAP speedup claims from the local timing evidence.

Parallelism: may run in parallel with Snow while both remain evidence-only. It should not run concurrently with another flow that changes `mod_kernel_transactions.f90` or the same surface-evaporation materialization path.

## Dependency graph

```text
F-GC28 canonical closure [A, fixed boundary]
        |
        +--> post-F-GC28 canonical state
                |
                +--> WOFOST81 F-CI84/F-CI89 [A]
                |
                +--> Snow exact process blob [science A]
                |       |
                |       +--> current serialized runtime/composition preservation [C]
                |               |
                |               +--> Snow current-canonical close/admit
                |
                +--> F-PE11 historical F-CI42/F-CI42P admission [A]
                        |
                        +--> later kernel-transaction dependency delta
                                |
                                +--> narrow current-head preservation replay [C]
                                        |
                                        +--> F-PE11 current-canonical close

F-KT16 Restart v1 [A] --> F-MR42 serialized MultiSWAP v1 [A]
                              |
                              +--> broader concurrent real-physics MultiSWAP [F]

F-TB11/F-TB12 preservation [A]
        |
        +--> optional deliberate future release/status rollup [F]

Existing adapter/runtime boundaries [A]
        |
        +--> broad stable external/public API [F]
        +--> wholesale legacy-IO removal [F]
```

## Recommended active capability flows

Only two flows should be active now:

1. **Snow current-canonical closure/admission.** Finish the already-running evidence-only current-canonical preservation path. This has higher priority because it closes a scientific/process capability whose production semantics are already proven and unchanged.
2. **F-PE11 current-head preservation/admission.** Run the narrow replay required by the direct kernel dependency delta. Keep the scope local and preserve the already admitted optimization semantics.

Do not start a third active capability flow yet. A release/testbank/theory rollup should wait until the two class-C items are closed or until an explicit release boundary is declared. Public API, wholesale IO migration and broader parallel MultiSWAP are not current blockers.

## Resume contract

Future sessions should begin from this file and perform a state-delta check only:

1. fetch `integration/f-ci-canonical` and compare its head with `bf0fb81daf0f0fee53566a426886eaa0d0ad2832`;
2. fetch the two class-C owner branches and inspect only changes since the heads recorded above;
3. if either capability has been canonically closed, move it from C to A without repeating repository-wide discovery;
4. reopen any A/F/E classification only if a relevant dependency or declared release requirement changed;
5. preserve the exclusions: no EB, no ROSS/RossFast, no Groundwater Coupling v1 reopening, no new physics and no production modification merely to obtain PASS.
