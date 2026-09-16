# SWAP5 Status-A documentation reconciliation matrix

Date: 2026-09-16

This file is the persisted pre-edit checkpoint for the post-Status-A documentation reconciliation workstream. It records the documentation state before any existing documentation file is edited.

## Pinned authority

- canonical branch: `integration/f-ci-canonical`
- current Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- current Status-A release-readiness record: `tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md`

The compare from the scientific production baseline to the current Status-A authority contains no scientific production change. The Status-A authority therefore governs current documentation scope while the production baseline remains the pinned scientific postimage.

## Classification vocabulary

- `A — CURRENT_AND_AUTHORITATIVE`
- `B — CURRENT_BUT_INCOMPLETE`
- `C — HISTORICAL_VALID_IN_CONTEXT`
- `D — STALE_OR_SUPERSEDED`
- `E — FUTURE_DESIGN_ONLY`
- `F — CONTRADICTS_CURRENT_CANONICAL_AUTHORITY`

Classification is about documentation authority, not whether an underlying scientific capability is admitted.

## Pre-edit reconciliation matrix

| Artifact or family | Class | Pre-edit finding | Required treatment |
| --- | --- | --- | --- |
| `tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md` | A | Current release-readiness authority. It explicitly closes the Status-A denominator and separates excluded future scope. | Preserve as primary current scope authority. Link from the refreshed documentation layer. |
| `docs/index.md` | B | Valid documentation landing page, but still frames the repository mainly as a target architecture being developed from SWAP 4.3.1 and does not identify the current Status-A boundary. | Refresh orientation and link the current Status-A authority. |
| `docs/architecture/overview.md` | E | Explicitly titled and written as target architecture. Several statements intentionally describe intended generic kernel/API/runtime architecture rather than bounded current Status-A functionality. | Preserve as future-design material and add a clear current-authority notice. Do not rewrite target history into current functionality. |
| `docs/architecture/component-map.md` | E | Explicit normative target component map, snapshot 2026-09-04. It says its implementation-status companion is the current progress authority. | Preserve target design; add notice that the current Status-A architecture map supersedes it for present implementation claims. |
| `docs/architecture/implementation-status.md` | F | Snapshot 2026-09-04 still calls transactional execution `IN_PROGRESS`, Restart/MultiSWAP-related architecture incomplete, groundwater interface `TARGET`, and multiple now-admitted seams unfinished. It also calls itself the central status register. This conflicts with the 2026-09-16 Status-A authority. | Preserve historical snapshot but mark explicitly superseded. Current status must move to a new Status-A page. |
| `docs/architecture/invariants.md` | B | Architecture invariants remain useful constraints, but their relationship to the admitted Status-A boundary is not made navigable from one current page. | Retain; reference from current architecture and traceability pages without expanding scientific claims. |
| `docs/architecture/legacy-migration*.md`, `migration-slices.md`, `m3-gate-evidence.md` | C/D | Migration records remain useful historical evidence, but they are not current capability status authority after canonical admission. Some completion language is necessarily stale. | Preserve. Add family-level supersession/navigation from current Status-A docs; edit individual files only where they make an explicit current-authority claim. |
| `docs/integration/F-CI*.md` | A/C | Hash-anchored integration/admission records are authoritative for the bounded capability decision they record. Earlier intermediate status statements remain historical after later gates. | Keep immutable decision history navigable through capability traceability. Do not treat an older intermediate gate as global current status. |
| `docs/testbank/` and permanent preservation records | A/B | Permanent preservation is part of the current Status-A authority. Existing material is capability-specific rather than a single current orientation layer. | Link current permanent suites and dependency-aware rerun rules from Status-A docs. |
| `docs/performance/` including F-PE11 material | A/C | F-PE11 semantics are canonically closed, but historical benchmark/qualification documents must not be read as a whole-model or MultiSWAP speedup claim. | Add bounded current description and preserve historical performance evidence. |
| `docs/verification/` | B | Verification principles remain relevant, but current capability-to-evidence-to-preservation navigation is distributed. | Add a Status-A traceability map; do not invent a master theory authority. |
| `docs/legacy/` | C | Legacy/reference documentation is required to understand preserved SWAP behaviour and migration constraints. It is not current SWAP5 architecture authority. | Preserve and cross-link as reference/historical authority. |
| `docs/decisions/` | C/A | ADRs preserve architectural decisions and rationale. Their date/context does not by itself establish current implementation status. | Keep as decision evidence; current implementation claims defer to Status-A authority. |
| `docs/development/` | B | Current development/governance material remains useful, but needs a direct rule for canonical admission, evidence inheritance and bounded dependency-triggered requalification. | Link or refresh only governance-facing orientation needed for Status-A. |
| RB1/RB2 and early Status-A material | C/D | No live-tree filename containing `RB1` was found in the initial canonical tree inventory. Any such records discovered by content search are historical unless later current authority explicitly adopts them. | Preserve when found; mark superseded where they make current claims that conflict with Status-A. |
| EB documentation and workflows | E | Present repository material does not place EB inside the current Status-A denominator. | Mention only as excluded/future scope in current Status-A documentation. No expansion. |
| ROSS/RossFast documentation and workflows | E | Present repository material does not place ROSS/RossFast inside the current Status-A denominator. | Mention only as excluded/future scope. No expansion. |

## Current authority precedence

For current Status-A claims, authority is interpreted in this order:

1. current canonical Status-A/release-readiness acceptance authority;
2. later capability-specific canonical admission/closure authority;
3. qualification evidence valid for the relevant unchanged dependency surface;
4. capability theory/scientific contract and implementation records;
5. historical migration/target-design documents.

A historical document is not made false by later progress. It becomes misleading only if it still presents an earlier state as current authority.

## Reconciliation conclusion before editing

The scientific/evidence layer is sufficiently authoritative to refresh documentation without reopening admitted capabilities. The principal documentation defect is not missing Status-A scientific evidence but authority ambiguity: the current landing/status layer still points readers toward a 2026-09-04 target/migration status model that is no longer current.

Next permitted phase: `UPDATE` documentation/governance files only. Production source is out of scope.