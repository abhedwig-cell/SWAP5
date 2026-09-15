# Post-F-GC28 residual capability audit

Date: 2026-09-16
Repository: `abhedwig-cell/SWAP5`
Canonical: `integration/f-ci-canonical`
Audit-only workunit. No production source is modified.

## Audit boundary and pinned state

The audit started from the exact post-F-GC28 canonical closeout at `3baf2aa135e3bf257942d9e6c5928990c2d1b2e1` (`close(F-GC28): record groundwater coupling v1 completion audit`). Canonical moved during the audit. A final state-delta check observed `50346642bd565f79134ea17d5462e544b354998c` (`close(F-PM02): current-canonical restricted Snow capability`). This final observed head is the resume baseline for this audit.

F-GC28 and Groundwater Coupling v1 are boundary conditions and are not reopened. EB, ROSS and RossFast are excluded.

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
| Snow restricted one-call daily migration and production admission | A | Closed during this audit. `F-PM02_CURRENT_CANONICAL_CLOSE.json` records F-CI90 admission, current-canonical runtime and restricted serialized MultiSWAP preservation, no missing gate, and no production change. Canonical close head is `50346642bd565f79134ea17d5462e544b354998c`. |
| Old Snow integration lineage `integration/f-mr06-snow` as an admission vehicle | E | Historical evidence remains useful, but the old integration lineage is superseded by the completed F-PM02 current-canonical closure. |
| Execution/performance policy for already admitted reference and serialized execution | A | Required execution contracts are present and repeatedly exercised by admission/preservation workflows. No residual policy implementation gap was found outside excluded ROSS/RossFast work. |
| F-PE11 surface-evaporation call-local allocation and scaling, current-head preservation | C | F-CI42/F-CI42P already admitted F-PE11 historically. The exact production binding remains qualified, but `mod_kernel_transactions.f90` moved later. The owner checkpoint requires a narrow current-head preservation replay and no duplicate semantic admission. |
| F-PE07 bounded parallel-v1 scaling characterization | F | Qualified characterization exists, but it is measurement evidence, not an unadmitted production capability. No current blocker follows merely from this branch. |
| State persistence and Restart v1 | A | F-KT16 completion authority closes Restart v1 at 100 percent. Later canonical work also contains parallel committed restart and coupled-restart admissions. |
| Serialized MultiSWAP v1 | A | F-MR42 completion authority closes the serialized MultiSWAP v1 scope. Permanent preservation infrastructure exists. |
| Restricted MultiSWAP restart already covered by admitted persistence/runtime contracts | A | Existing restart and serialized runtime authorities cover the admitted restricted functionality; no distinct residual implementation gap was found. |
| Parallel/concurrent real-physics MultiSWAP beyond admitted serialized functionality | F | This is broader execution scope. No evidence establishes it as a current blocker, and it must not be inferred as missing from experimental/performance branches. |
| Internal transactional orchestration used by canonical runtime | A | Canonical contains transaction/runtime/adapter layers consumed by later admitted capabilities. No residual internal orchestration gap was identified. |
| General stable public/external SWAP5 orchestration API beyond admitted adapters | F | A broad public API contract is not established as a current release prerequisite. Existing adapter work must not be generalized into an invented API requirement. |
| Legacy IO isolation as a complete de-legacy migration | F | Canonical deliberately retains `src/legacy` beside adapter/runtime/process layers. No current authority makes complete legacy-IO removal a prerequisite. |
| Existing IO/adapter boundaries used by admitted capabilities | A | Current source architecture separates adapter, runtime, process, transaction and legacy areas. Admitted capabilities use these boundaries without requiring a wholesale IO rewrite. |
| Drainage process migration/runtime admission | A | Drainage was admitted and subsequently adopted into permanent preservation by F-TB12/F-TB12P. |
| Surface-evaporation process migration chain underlying the admitted reference path | A | F-PM06 sub-capabilities are represented in canonical admission history; F-PM06G is owner-closed. The only residual item found on this surface is F-PE11 current-head preservation, classified separately as C. |
| WOFOST81 preservation and runtime activation through F-CI89 | A | Canonical closed F-CI89 before the Snow F-CI90 closure. |
| Remaining non-EB/non-ROSS process migrations not tied to an explicit current acceptance criterion | F | No additional concrete current blocker was found. Historical branches alone are insufficient evidence of an open capability. |
| Generic repository-wide scientific/numerical requalification | F | Qualification remains capability-scoped. No evidence supports reopening all science/numerics globally. No standalone current scientific gap remains after Snow closure. |
| Permanent testbank preservation machinery | A | F-TB11 establishes permanent preservation for its protected closed set; F-TB12 adds drainage and F-TB12P reconciles its postimage. |
| RB1/RB2 restricted production baseline authority in its historical scope | A | The historical release baseline is closed for its declared scope. |
| New release qualification snapshot for the moving post-RB2 canonical | F | Canonical has advanced substantially since RB1/RB2, but no release cut was requested or established as a current blocking capability. Create a new release authority only when a release boundary is intentionally declared. |
| Historical RB1 Status-A documentation used as current canonical truth | E | F-DOC17/F-DOC18 era authorities predate hundreds of later canonical commits. They remain historical evidence, not a live global status source. |
| Current global theory/documentation/code/evidence rollup | F | A fresh global rollup is useful at a deliberate release/status boundary, but its absence does not imply missing production semantics. Capability-local evidence remains authoritative. |
| Early central architecture/status snapshots contradicted by later admission evidence | E | Older snapshots describe later-closed transaction/coupling capabilities as target/partial. They must not drive current residual-gap decisions. |

No candidate is classified B or D. The audit found no justified new production implementation gap in the in-scope post-F-GC28 residual surface.

## Canonically closed Snow detail

The decisive current-canonical Snow close authority is `integration/f-pm/F-PM02_CURRENT_CANONICAL_CLOSE.json` on canonical. It records:

- owner workunit F-PM02 and admission workunit F-CI90;
- canonical admission parent `bf0fb81daf0f0fee53566a426886eaa0d0ad2832`;
- admission head `bfd2c57e0b5e7f578f2635379e996419e1f7edfa`;
- final canonical close head `50346642bd565f79134ea17d5462e544b354998c`;
- decisive qualification head `25d83778dcade34225b4630059fd43142f95193d`;
- F-VQ16 independent scientific qualification remains valid;
- current-canonical runtime preservation and restricted serialized MultiSWAP preservation are reestablished;
- no admission gate remains and no production source change was required.

Closed scope remains restricted to exact one-call daily Snow, fail-closed unsupported durations, correct checkpoint/trial/retry/commit isolation, existing Snow mass semantics and serialized real-physics MultiSWAP with maximum one simultaneous physical solve. It does not admit broader Snow durations, parallel real physics or performance claims.

## Open class-C detail

### F-PE11 surface-evaporation allocation/scaling preservation

Owner branch and current observed head: `performance/f-pe11-surface-evaporation-allocation-scaling` at `ac967e3f0f5144f905aac65f2ea9c4c996f2e9a7`.

Qualified postimage/evidence retained by the owner checkpoint:

- qualified head `a0b810bf68d5b5228da5f39ce9e30fc41ddd6954`;
- production binding blob `67b346251ba21be62c6ed3077f2c71ddd2c8dd02`;
- qualified materialization blob `bc40bc6b121f56071d2b811195759f86130defeb`;
- closeout head `b436f8e70664cdb851f20f148463459358568579`;
- F-CI42 performance admission retained;
- F-CI42P post-promotion governance retained;
- F-CI59P materialization postimage/permanent-preservation evidence retained;
- owner O0/O2 identity, committed-state immutability, A-B-A determinism, scientific identity and mass nonchange retained.

Relevant dependency: `src/kernel/mod_kernel_transactions.f90` changed after the prior materialization postimage. The F-PE11 production binding is unchanged and the surface-evaporation equations did not change. The checkpoint explicitly says duplicate semantic admission is not required if a narrow preservation replay passes.

Minimum next gate: compose against current canonical at or after `50346642bd565f79134ea17d5462e544b354998c` without production edits, confirm the newly admitted Snow evidence-only closure does not affect the F-PE11 dependency surface, run the existing narrow F-PE11 functional preservation plus paired local timing workflow, then record current-head preservation/closure. Do not make whole-model or MultiSWAP speedup claims from local timing evidence.

Parallelism: F-PE11 can proceed independently of future IO/API/release-documentation work, but should not run concurrently with another flow that changes `mod_kernel_transactions.f90` or the same surface-evaporation materialization path.

## Dependency graph

```text
F-GC28 canonical closure [A, fixed boundary]
        |
        +--> WOFOST81 F-CI84/F-CI89 [A]
        |
        +--> Snow F-PM02/F-CI90 current-canonical closure [A]
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

Only one active capability flow is justified now:

1. **F-PE11 current-head preservation/closure.** Run the narrow replay required by the direct kernel dependency delta. Keep the scope local and preserve the already admitted optimization semantics.

Do not create a second or third active flow merely to fill capacity. Snow is closed. Public API, wholesale IO migration, broader parallel MultiSWAP and a new release/theory rollup are not current blockers. A release/testbank/theory rollup should begin only when an explicit release or Status-A refresh boundary is declared.

## Resume contract

Future sessions should begin from this file and perform a state-delta check only:

1. fetch `integration/f-ci-canonical` and compare its head with `50346642bd565f79134ea17d5462e544b354998c`;
2. fetch `performance/f-pe11-surface-evaporation-allocation-scaling` and inspect only changes since `ac967e3f0f5144f905aac65f2ea9c4c996f2e9a7`;
3. if F-PE11 has been canonically/current-head closed, move it from C to A without repeating repository-wide discovery;
4. reopen any A/F/E classification only if a relevant dependency or an explicit release requirement changed;
5. preserve exclusions: no EB, no ROSS/RossFast, no Groundwater Coupling v1 reopening, no new physics and no production modification merely to obtain PASS.
