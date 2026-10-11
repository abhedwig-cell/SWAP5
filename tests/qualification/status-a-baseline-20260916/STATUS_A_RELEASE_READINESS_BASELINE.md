# SWAP5 current-canonical Status-A / release-readiness baseline

Date: 2026-09-16

## Authority and bounded scope

This record is a reconciliation, qualification and release-governance authority only. It does not modify production semantics.

Pinned canonical at qualification start:

- branch: `integration/f-ci-canonical`
- commit: `50346642bd565f79134ea17d5462e544b354998c`
- tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- canonical commit: `close(F-PM02): current-canonical restricted Snow capability`

Resume authority:

- post-F-GC28 residual capability audit: `bd12071d2ce45e21306a38c3a57edf60bf28dd4b`
- audit canonical authority: the same commit/tree pair pinned above
- F-PE11 current-canonical NO_OP closure: `f928f309d21c18679977cc3d2c4a76f7c3be04c6`
- F-PE11 post-close metadata checkpoint: `00d735939cb4a8da8b027b20b7dd25725cd73526`

Explicit exclusions from the Status-A denominator:

- EB
- ROSS / RossFast
- new physics
- production optimization beyond already admitted semantics
- broad MODFLOW backend work
- API or IO implementation merely because future scope exists
- concurrent real-physics MultiSWAP
- arbitrary-duration or advanced-melt Snow
- reopening canonically closed capabilities without dependency evidence

## RECONCILE

A state-delta check was performed from the post-F-GC28 residual audit rather than reconstructing repository history.

The post-F-GC28 audit already ran against exactly the pinned current-canonical commit and tree. The canonical branch has not moved since that audit baseline. The only subsequent relevant F-PE11 activity is qualification-branch evidence metadata. F-PE11 records that the later Snow closure changed only Snow preservation/metadata surfaces and did not change production, reference or F-PE11 dependency-sensitive sources. Therefore immutable evidence for unchanged capabilities remains authoritative.

### Material capability classification

| Capability | Class | Current authority / basis |
| --- | --- | --- |
| Reference / legacy scientific preservation, including O0/O2 reference equality | A — CANONICALLY_CLOSED | Same-tree F-GC29 bounded replay and permanent reference gates |
| Transactional solver and orchestration architecture | A — CANONICALLY_CLOSED | Canonical transactional solver/orchestration sources plus permanent transactional suite |
| Restart v1 | A — CANONICALLY_CLOSED | Same-tree F-GC29 restart observable and mass-preservation replay |
| Serialized MultiSWAP v1 | A — CANONICALLY_CLOSED | Same-tree F-GC29 observable and aggregate-mass replay |
| Drainage | A — CANONICALLY_CLOSED | Canonical admission plus moving-current preservation legs A and B in F-GC29 |
| Surface evaporation | A — CANONICALLY_CLOSED | Canonical admission plus moving-current inner-step free-water-head provenance preservation |
| WOFOST81 admitted runtime scope | A — CANONICALLY_CLOSED | F-CI89 admission/closure in canonical history plus same-tree scientific gates |
| Restricted one-call-daily Snow | A — CANONICALLY_CLOSED | F-PM02 admission/closure; exact-head canonical Snow preservation workflow succeeded |
| Groundwater Coupling v1 | A — CANONICALLY_CLOSED | F-GC27/F-GC28 canonical closure plus targeted and mixed-smoke qualification in F-GC29 |
| F-PE11 admitted/current-head-preserved performance semantics | A — CANONICALLY_CLOSED | F-CI42/F-CI42P canonical semantics; F-PE11 current-head NO_OP preservation closure |
| Permanent testbank authorities | A — CANONICALLY_CLOSED | Permanent baseline, smoke, kernel, transactional, independent-oracle, mixed-smoke and numerical suites retained on pinned tree |
| Current scientific/numerical qualification authorities | A — CANONICALLY_CLOSED | Immutable same-tree authorities retained; no dependency invalidation detected |
| Release and regression workflow coverage for admitted scope | A — CANONICALLY_CLOSED | Same-tree F-GC29 workflow reconciliation; exact-head Snow preservation run green |
| Theory/governance for admitted Status-A capabilities | A — CANONICALLY_CLOSED | Capability-level theory/code/evidence/admission/preservation map reconciled by F-GC29 |
| Historical single-column assumptions, dead flags and superseded architectural wording | E — STALE_OR_SUPERSEDED | Historical documentation only; not production authority |
| Old branch/web summaries superseded by hash-anchored evidence | E — STALE_OR_SUPERSEDED | Superseded by canonical/evidence commit authorities |
| Parallel/concurrent real-physics MultiSWAP | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | Explicitly excluded from denominator |
| Arbitrary-duration / advanced-melt Snow | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | Current admitted Snow scope remains restricted one-call-daily |
| Broad MODFLOW/backend evolution | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | Groundwater Coupling v1 is the current accepted boundary |
| Broad public API / wholesale legacy IO modernization | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | No current Status-A acceptance requirement |
| Speculative production optimization | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | No current Status-A acceptance requirement |
| Coupled crop/groundwater extensions beyond admitted interfaces | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | Not part of current accepted scope |
| Ownership/helper cleanup without scientific or numerical defect | F — FUTURE_SCOPE_NOT_A_CURRENT_BLOCKER | Maintenance scope only |

Classes B, C and D inside the declared Status-A denominator: **none**.

No gap is inferred from an old branch. No future-scope item is promoted to a blocker.

## QUALIFY

No historical campaign was rerun blindly. Qualification follows dependency-aware evidence inheritance.

### Immutable whole-baseline evidence inherited

The F-GC29 residual audit was executed against the exact commit/tree pinned by this baseline. It reports PASS for:

- direct legacy/reference checksum equality at O0 and O2;
- scientific gates, including reference checksum, reference closure, bare-soil ponding, WOFOST smoke and extended checks;
- Restart v1 observable and mass preservation;
- serialized MultiSWAP v1 observable and aggregate mass preservation;
- drainage canonical preservation;
- surface-evaporation moving-current contract;
- restricted Snow moving-current preservation;
- Groundwater Coupling v1 targeted tests and mixed smoke;
- permanent suites `tests/run-baseline.sh`, `tests/run-smoke.sh`, `tests/run-kernel.sh`, `tests/run-transactional.sh`, `tests/run-independent-oracle.sh`, `tests/run-mixed-smoke.sh`, and `tests/run-numerical.sh`.

Because current canonical has exactly the same tree as that qualification authority, repeating these suites would not add independent current-head information. Their evidence is inherited unchanged.

### Moving-current replay / post-audit state delta

- Restricted Snow: GitHub Actions workflow `F-PM02 Canonical Snow Preservation` ran on exact canonical head `50346642...` and completed successfully.
- F-PE11: post-close state-delta evidence confirms that the only delta relative to its frozen authority is Snow-scoped metadata/preservation files. No production, reference or performance-dependency-sensitive source changed. Its NO_OP closure therefore remains valid without a benchmark rerun.
- No other admitted capability surface changed after the same-tree F-GC29 replay. No additional moving-current gate is triggered by dependency delta.

### Qualification verdict

`PASS_CURRENT_CANONICAL_BASELINE`

No silent loss of qualified semantics was observed. No current-head production repair was required or attempted.

## THEORY / DOCUMENTATION / EVIDENCE RECONCILIATION

The authoritative relation for admitted scope is:

`theory / contract -> production code -> qualification evidence -> canonical admission -> preservation test`

Current global mapping:

| Domain | Production authority | Qualification authority | Admission authority | Preservation authority | Reconciliation |
| --- | --- | --- | --- | --- | --- |
| Reference preservation | legacy/reference controllers | O0/O2 checksum and closure gates | canonical reference contract | permanent reference gates | consistent |
| Transactional architecture | transactional solver/orchestration sources | transactional + numerical suites | canonical architecture chain | permanent transactional suite | consistent |
| Restart v1 | restart/lifecycle implementation | restart observable + mass tests | canonical Restart v1 admission | permanent restart regression | consistent |
| Serialized MultiSWAP v1 | serialized MultiSWAP implementation | observable + aggregate mass tests | canonical MultiSWAP v1 admission | permanent MultiSWAP regression | consistent |
| Drainage | admitted drainage implementation | independent/current preservation evidence | canonical drainage admission | drainage preservation legs | consistent |
| Surface evaporation | admitted evaporation implementation | provenance/current preservation evidence | canonical surface-evaporation admission | moving-current preservation | consistent |
| WOFOST81 admitted scope | admitted WOFOST81 runtime path | scientific WOFOST gates | F-CI89 canonical admission/closure | permanent scientific gates | consistent within admitted scope |
| Restricted Snow | restricted one-call-daily implementation | Snow scientific/runtime/MultiSWAP authorities | F-PM02 canonical admission/closure | exact-head Snow workflow | consistent within restricted scope |
| Groundwater Coupling v1 | admitted groundwater coupling interfaces/trajectory semantics | F-GC qualification chain + mixed smoke | F-GC27/F-GC28 canonical closure | targeted/permanent regression | consistent |
| F-PE11 semantics | F-CI42/F-CI42P admitted implementation | immutable performance-preservation evidence | already canonical; F-PE11 NO_OP close | dependency-aware current-head preservation | consistent |

Historical documentation that still describes superseded single-column assumptions, dead flags or pre-admission architecture is classified as documentation lag/stale history, not current authority. It should remain historically honest and be corrected prospectively rather than rewritten as if it were never true.

Current distinction:

- documentation lag: present, historical/stale only;
- missing evidence inside denominator: none observed;
- genuine code defect inside denominator: none observed;
- deliberate future scope: explicitly classified F and excluded from release blocking.

## RELEASE DECISION

Declared Status-A denominator consists only of the class-A admitted scope listed above. There are no B, C or D items inside that denominator.

Verdict: **READY_FOR_STATUS_A_RELEASE_CANDIDATE_BOUNDARY**.

This verdict does not assert completion of future-scope capabilities and does not extend scientific scope beyond already admitted contracts.

## Residual risks and non-blocking governance observations

- `integration/f-ci-canonical` is presently not branch-protected and the pinned canonical close commit is unsigned. This is an operational repository-governance risk, not evidence of a scientific or numerical defect. It is not promoted into the current Status-A scientific denominator by this workunit.
- Historical documentation drift remains. Hash-anchored canonical/evidence authorities take precedence where old narrative text conflicts with admitted state.
- Future changes to production/reference/dependency-sensitive surfaces invalidate inheritance only for the capabilities they actually touch.

## CLOSE / resume contract

Future sessions shall resume from this baseline using state delta only:

1. fetch live `integration/f-ci-canonical` and compare commit/tree to `50346642bd565f79134ea17d5462e544b354998c` / `3b085d7dea3d3f3fce42ad9d8f259a8350205846`;
2. inspect only changed files and their owning capability/dependency surfaces;
3. inherit immutable evidence for untouched capabilities;
4. replay only moving-current preservation gates whose dependency surfaces changed;
5. reclassify only touched capabilities or capabilities brought into the denominator by an explicit new acceptance requirement;
6. do not reopen EB, ROSS/RossFast, advanced Snow, parallel real-physics MultiSWAP, broad MODFLOW, wholesale IO/API modernization or speculative optimization absent an explicit denominator change;
7. never modify production semantics merely to obtain a release qualification PASS.

Next permitted actions after admission of this evidence-only authority:

- create a Status-A / release-candidate tag or release authority anchored to the admitted baseline postimage;
- separately improve repository governance such as branch protection/signing without changing scientific scope;
- pursue class-F capabilities only as separately scoped future workunits.
