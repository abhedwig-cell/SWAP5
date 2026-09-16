# SWAP5 Status-A documentation refresh closeout

Date: 2026-09-16
Workstream: post-Status-A current-canonical documentation reconciliation and refresh
Protocol: `RECONCILE -> UPDATE -> VERIFY -> CLOSE`

## Authority used

- canonical branch: `integration/f-ci-canonical`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- current release-readiness authority: `tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md`

No production or reference source was modified by this workstream.

## RECONCILE result

The pre-edit documentation source-of-truth matrix is persisted in `docs/status-a/DOCUMENTATION_RECONCILIATION_MATRIX.md`.

The principal conflict was authority ambiguity rather than missing scientific evidence. The 2026-09-04 architecture/status layer still presented target and migration state as if it were the current status authority, while the later Status-A acceptance record had already closed the admitted denominator.

The current Status-A release-readiness record is the umbrella authority for current scope. Capability-specific scientific contracts, qualifications, admissions and immutable evidence remain distributed and are not replaced by a fabricated master theory file.

## UPDATE result

Current Status-A documentation was added for:

- current capability and scope boundary;
- current transaction/state/runtime architecture;
- theory to code to evidence to admission to preservation traceability;
- deliberate future/non-admitted scope;
- the documentation reconciliation matrix.

The documentation landing page and MkDocs navigation now route present-state questions to the Status-A layer first.

Historical/target records explicitly reclassified for present-state use:

- `docs/architecture/implementation-status.md`: preserved as the 2026-09-04 historical migration-status snapshot and superseded for current-state claims;
- `docs/architecture/overview.md`: preserved as target-design material, not current implementation authority;
- `docs/architecture/component-map.md`: preserved as target component ownership design, not current implementation authority.

No historical scientific or architectural conclusion was rewritten to pretend that later admission had already existed at the earlier snapshot date.

## Current architecture map established

The current layer distinguishes these responsibilities:

- legacy/reference;
- process;
- solver;
- runtime/transaction;
- committed persistent state;
- candidate/trial state;
- scratch/workspace;
- persistence/restart;
- serialized MultiSWAP orchestration;
- coupling/adapter;
- diagnostics;
- test/qualification infrastructure.

Current ownership is documented so that solver/process calculation does not itself commit state; transaction/runtime owns trial lifecycle and commit/rollback; committed state is authoritative; candidate state remains tentative until acceptance; scratch/workspace has no independent persistence authority; process contracts own their physical flux/storage definitions; external publication is bounded by accepted coupling state; and execution policy is separate from solver calculation.

## Current capability/status map established

The current documentation records these admitted Status-A capability families within their bounded contracts:

- reference preservation;
- Richards/soil-water admitted core;
- transactional execution and trial/accept/retry/rollback;
- explicit state ownership and solver/execution-policy separation;
- Restart v1;
- serialized MultiSWAP v1;
- drainage;
- surface evaporation;
- bounded WOFOST runtime scope;
- restricted one-call-daily Snow;
- Groundwater Coupling v1;
- external groundwater gateway boundary;
- bounded F-PE11 semantics;
- permanent testbank/qualification architecture and current same-tree preservation evidence.

F-PE11 is documented according to its close authority: admission action `NO_OP`, no production/reference mutation, preservation/non-regression evidence only, and no whole-model speedup, MultiSWAP speedup or portable speed guarantee.

## Preservation authority correction

During VERIFY, an over-broad draft statement was found and corrected. `docs/testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md` is explicitly bound to older canonical `379afd11...` and cannot itself be cited as the preservation authority for Status-A head `992a5c657...`.

The refreshed documentation now treats F-TB11 as an important permanent-testbank architecture/historical snapshot and uses the current Status-A release-readiness record for the later same-tree preservation conclusion. That record inherits the F-GC29 replay and reports PASS for the permanent baseline, smoke, kernel, transactional, independent-oracle, mixed-smoke and numerical suites, plus capability-specific moving-current/exact-head evidence where required.

This also resolves the historical Drainage mismatch: F-TB11 did not yet credit Drainage at its snapshot, while the later Status-A authority records Drainage as canonically closed and preserved by F-GC29 moving-current legs.

## Future-scope map

The current documentation explicitly keeps the following outside the Status-A denominator unless a future acceptance authority changes that boundary:

- EB;
- ROSS / RossFast;
- arbitrary-duration, subdaily or advanced Snow beyond the restricted admitted path;
- parallel/concurrent real-physics MultiSWAP;
- broad MODFLOW/backend evolution;
- wholesale legacy IO modernization;
- a broad stable public API;
- speculative production optimization and unqualified execution modes;
- other extensions not admitted by current Status-A authority.

Absence from Status-A is not described as a defect unless an applicable acceptance authority says so.

## VERIFY result

Pull request `#152` exercises the repository documentation workflow.

On documentation head `ac5b3286cb2fc79e326fea672bc3bd3ba002dd18`, workflow run `35041559028` completed successfully. Job `Validate and build` passed both repository gates:

- `python tools/docs/check_docs.py`: PASS;
- `mkdocs build --strict`: PASS.

The source checker validates MkDocs navigation targets, repository-relative Markdown links, the exact 1..30 architecture invariant sequence and absence of a tracked generated `site/` directory.

The adversarial consistency pass also checked for stale current blocker wording around Groundwater and Snow and for an over-broad F-PE11 speedup claim. No separate conflicting current claim was found in those searches. The central 2026-09-04 implementation-status page and target architecture pages were the material current-authority conflicts and are now explicitly historical/target for present-state use.

Final branch-delta verification must continue to require that the workstream changes documentation/governance material only. No production source repair is permitted to satisfy documentation checks.

## Known remaining documentation gaps

Historical migration, qualification and capability records remain numerous and intentionally preserve their dated local conclusions. Not every historical record has received an individual superseded banner. This is acceptable only because the current landing/status layer establishes authority precedence and the principal central conflicting pages are explicitly marked.

The documentation does not attempt to replace distributed capability records with one master theory file. Exact low-level source-path traceability remains capability-specific where the owning qualification/admission record is the proper authority.

The parallel SWAP 4.3.1 to SWAP5 equivalence campaign is not required for this closeout. Accepted results from that campaign can later be linked as additive validation evidence without rewriting the core Status-A denominator.

## Final verdict

`DOCUMENTATION_CURRENT_WITH_NONBLOCKING_HISTORICAL_GAPS`

Rationale: current Status-A authority, admitted scope, actual architecture, ownership boundaries, preservation model, future-scope boundary and authority precedence are now explicit and internally buildable. Remaining gaps are historical-navigation granularity, not missing evidence or a known production/scientific defect inside the Status-A denominator.