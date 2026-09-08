# SWAP5 test architecture

F-TA01 introduces a registry and evidence hierarchy. It does not requalify production source and it does not change production code. The baseline is qualification head `65efc66cc76fa9005eac46e5779439c5ada574d1`, whose F-VQ15 evidence admits exact candidate source `c28e7a2810b4a3678c577335a6a3086b173eb976`, tree `a1a161e5e33fc143a7dc7f3c1b9749fc96f861f6`, only for the restricted serialized multicolumn profile stated by F-VQ15.

## Stable identifiers

The prefix states what kind of evidence a test can produce:

| Prefix | Meaning | Upper evidence boundary |
|---|---|---|
| `UT` | unit test | local implementation behavior |
| `CT` | component or contract test | named component or interface contract |
| `IT` | focused integration test | integration across the named dependency seam |
| `INV` | explicit invariant test | only the named invariant and tested scope |
| `RR` | reference regression | difference against the named and pinned oracle |
| `QG` | qualification gate | formal admission only when exact source and evidence are bound |

IDs are derived from the tracked artifact path in F-TA01 and remain aliases if a file later moves. Existing work-unit names such as F-CI11 and F-MR05 remain traceable aliases. A rename therefore requires an explicit registry migration, not silent ID regeneration.

## Cost classes and selection

`FAST` is expected to complete in seconds and covers structural validation, compiler diagnostics, and small unit or contract tests. `FOCUSED` exercises a component and its direct dependency seam. `BROAD` crosses several subsystems or runs a wider regression matrix. `QUALIFICATION` is a formal source-bound gate with preserved evidence.

The selection sequence is:

1. declare the source change in a verification contract;
2. map its source surface and dependency type;
3. run required `FAST` checks;
4. run direct and dependency-cone `FOCUSED` tests;
5. persist the usable postimage and record its commit and tree;
6. run `BROAD` or `QUALIFICATION` only when the impact map or declared semantic change requires it.

The impact map is advisory and fail-closed. Unknown ownership expands the cone or creates a blocker. It may not suppress testing. No broad or qualification run may begin before `checkpoint_commit` and `checkpoint_tree` identify the persisted postimage.

## Evidence hierarchy and proof boundaries

The general hierarchy is unit, component/contract, focused integration, scientific invariant, reference regression, broad qualification. Passing a lower layer is necessary where selected, but never automatically proves a higher layer.

- A unit test does not prove integrated physical equivalence.
- Equality to legacy output proves compatibility with that oracle, not scientific correctness.
- A broad green regression does not prove rollback unless rollback state and diagnostics were directly observed.
- Mass conservation is a separate hard assertion. Rounded reports are not an adequate oracle.
- A qualification result applies only to its exact source commit/tree, fixtures, compiler/runtime conditions, tolerance policy and declared scope.
- Historical evidence remains historical. Registration does not upgrade its status or transfer it to the F-TA head.

For structural refactors with no intended physics or numerical change, differential tests should compare the qualified preimage and candidate postimage. The comparison should include relevant committed state, fluxes, unrounded mass accounting, transaction diagnostics, and solver/result status. If behavior is intended to change, the verification contract must name the expected differences before execution. Unlisted differences fail closed.

## Inventory interpretation

`test-architecture/test-register.json` inventories tracked test sources, runners, qualification workflows, VQ gates, corrected-reference gates, and reference-patch gates visible on this baseline. Support sources and workflows are recorded because they affect reproducibility, but `NOT_DIRECTLY_EXECUTABLE` artifacts cannot independently produce evidence. Every record is marked `DISCOVERED_NOT_REEXECUTED_FTA01`; prior evidence is not erased, but F-TA01 does not claim to have replayed it.

F-MQ evidence exists on qualification branches outside this baseline. F-TA01 records that absence as a blocker instead of copying or upgrading evidence without a controlled lineage decision.

## Testability blockers

| ID | Blocker | Required owner | F-TA01 treatment |
|---|---|---|---|
| `FTA01-B01` | No canonical machine-readable process-level map for `src/legacy/b1_10_port/**` to physics, mutable state, solver policy and tests. | F-SI with later canonical integration | Keep impact selection broad and `NOT_ASSESSED`; do not modify the production interface. |
| `FTA01-B02` | Precision-policy ownership and affected output surfaces are not declared as a production contract. | F-SI/F-CI or later production integration | Require manual declaration and fail closed for precision-related changes. |
| `FTA01-B03` | Several test sources and stubs have no standalone runner, fixture declaration or explicit tolerance metadata. | Owning workstream | Register as supporting or not directly executable; do not infer proof value. |
| `FTA01-B04` | F-MQ harnesses/evidence are not present in the selected exact F-VQ15 baseline tree. | F-MQ/F-CI lineage owner | Record off-lineage evidence; admission into a canonical test baseline needs a separate controlled merge or qualification unit. |
| `FTA01-B05` | No qualified selector proves that automated dependency-cone reduction is complete. | F-TA02 | Keep the impact map advisory and expand unknown cones. |
| `FTA01-B06` | Exact preimage/postimage observation is not uniform across state, flux, unrounded mass, transaction diagnostics and solver status. | F-KT, F-SI, F-CI, F-MR by owned interface | Declare the missing observation surface and hold equivalence claims; no production changes in F-TA. |

## Files and validation

- `test-architecture/test-register.json`: generated machine-readable inventory.
- `test-architecture/test-register.schema.json`: structural schema.
- `test-architecture/test-impact-map.json`: first source/component impact map.
- `test-architecture/verification-contract-template.json`: required future work-unit declaration.
- `tools/test_architecture/build_registry.py`: deterministic repository discovery plus explicit suite metadata.
- `tools/test_architecture/validate_test_architecture.py`: cheap fail-closed coverage and field validation.

Run `python3 tools/test_architecture/build_registry.py` followed by `python3 tools/test_architecture/validate_test_architecture.py`. Regeneration is reviewable: a new tracked test or workflow must appear in the register, while the validator rejects unregistered artifacts.

## F-TA02 impact-selection validation

F-TA02 adds an executable advisory selector and a pinned historical replay corpus. The corpus covers a kernel checkpoint change, explicit solver controls, runtime diagnostics, the authoritative mass contract, a corrected-reference manifest, and a governance-only change. It verifies that the selector includes minimum expected test families and cost classes. Two negative cases verify fail-closed behavior for an unmapped production path and for missing semantic declarations.

This is deliberately a limited claim. Six retrospective cases do not prove that the dependency map is complete, and the selector has no authority to waive a test or grant qualification. Its output is `SELECTION_PROPOSED_NOT_QUALIFICATION` or `BLOCKED`.

`test-architecture/legacy-process-ownership.json` now maps every file in the current `src/legacy/b1_10_port` directory at file level. The four assembled `swap_part*.inc` files remain `NOT_ASSESSED_FINE_GRAIN`, because their internal process boundaries have not been qualified. `test-architecture/fixture-tolerance-audit.json` records explicit, partial, unknown, external and off-lineage provenance without filling gaps by inference.
