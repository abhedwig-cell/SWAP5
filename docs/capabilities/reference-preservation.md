# Reference preservation

Reference preservation is the evidence chain that lets SWAP5 change software structure without silently changing the already-admitted scientific behaviour of the frozen Status-A denominator.

It is **not** one checksum, one regression script, or a claim that every historical SWAP option is bitwise identical under every possible input. Preservation is capability-bounded and authority-bounded.

## Frozen denominator

The Status-A review separates two exact anchors:

- frozen Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`, tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`.

The first is the review/release authority. The second fixes the scientific production postimage used by the Status-A qualification. Later documentation, governance or post-Status-A development does not silently enlarge that scientific denominator.

## What “preserved” means

For an admitted capability, the evidence chain is:

`reference/scientific contract -> production implementation -> qualification -> canonical admission -> preservation`

A preservation result therefore means that the **specific observables and invariants named by that authority** still hold for the pinned dependency surface. Depending on the capability, those observables can include exact checksums, closure, mass completeness, committed-state behaviour, continuation state, publication ownership or source/reference identity.

A PASS is not a universal theorem about every future input or every historical SWAP mode.

## Five preservation layers

| Layer | Purpose | Status-A example |
|---|---|---|
| Frozen identity | Fix exactly what scientific code/reference state is under review. | production commit `50346642...`, tree `3b085d7d...` |
| Capability qualification | Establish a bounded scientific/numerical contract against exact source/reference authority. | F-SI33 Full Richards Reference Solver v1 |
| Canonical admission | Make the qualified capability part of accepted SWAP5 state. | capability-specific admission chain inherited by Status-A |
| Permanent preservation role | Give admitted behaviour a stable regression role without copying every historical qualification suite. | F-TB11 stable IDs such as `FTB11-FR-001` |
| Current/same-tree reconciliation | Reuse immutable evidence when dependencies are unchanged and replay only gates whose protected surface changed. | Status-A release-readiness reconciliation |

This layering is why a historical qualification run can remain valid evidence without automatically being current-head proof after relevant source changes.

## Full Richards / scientific-reference authority

F-SI33 is the bounded completion authority for the frozen Full Richards Reference Solver v1. Its completion report records PASS for production/reference binding, solver isolation, nonlinear/linear solve, temporal reference accuracy, mass, restart, MultiSWAP equivalence, sensitivity and preservation, with no production/reference source change by F-SI33 itself.

The claim is still denominator-specific. F-SI33 explicitly does not qualify RossFast or another alternative production solver, does not create a universal nonlinear true-error bound, and does not add future coupling or physics scope.

F-TB11 then assigns the stable role `FTB11-FR-001` to Full Richards/reference preservation with exact source/reference provenance. This is a preservation role over already-qualified behaviour, not a second scientific model definition.

## Permanent testbank versus current-source replay

F-TB11 deliberately distinguishes immutable authority from moving replay.

The concrete frozen runner

```text
testbank/runners/run_ftb11_current_source_replays.sh
```

materializes independently qualified F-VQ65/F-VQ71 verifier sources against its pinned canonical worktree. Among other stable roles, it protects:

- transaction and mass fail-closed semantics (`FTB11-TXN-001`, `FTB11-MASS-001`);
- restart continuation (`FTB11-RST-001`);
- serialized MultiSWAP continuation (`FTB11-MSW-001`);
- rejected/publication ownership semantics (`FTB11-REJECT-001`, `FTB11-ETPUB-001`).

F-TB11 also retains source locks for the Full Richards/reference role and mandatory solver seam. Older executable fixtures whose acceptance contracts became stale are deliberately kept as historical evidence rather than silently repaired and relabelled as current oracles.

That distinction is central to SWAP5 preservation: **historical evidence remains historically true; current preservation must use an oracle whose contract still matches the current dependency surface.**

## Checksum, closure and optimisation-mode identity

The Status-A release-readiness authority reports same-tree PASS for direct legacy/reference checksum equality at O0 and O2 and for reference closure, together with the applicable scientific and numerical gates.

These statements are strong because they are tied to an exact tree and exact qualified fixtures. They should nevertheless be read literally:

- checksum equality proves equality of the compared output represented by that checksum;
- closure proves the closure criterion exercised by that gate;
- O0/O2 identity proves that the qualified observable is unchanged between those compiler optimisation modes;
- none of these statements alone proves all possible observables for all possible configurations.

Where mass completeness, transaction ownership or continuation semantics matter, those are protected by their own qualified gates rather than inferred from a reference checksum.

## Evidence inheritance and invalidation

SWAP5 does not rerun every historical campaign after every commit. Immutable evidence is inherited while its relevant dependencies are unchanged.

When a relevant source or contract changes, the correct sequence is:

1. identify which admitted capability depends on the changed surface;
2. keep unrelated immutable evidence intact;
3. replay or requalify the affected preservation role against the changed postimage;
4. record new evidence before treating the changed head as preserving that capability.

A documentation-only change does not by itself invalidate scientific qualification. Conversely, a green historical run must not be treated as current-head proof after its protected source changes.

## Historical suite labels are not repository paths

The historical Status-A release-readiness narrative uses names such as `tests/run-baseline.sh`, `tests/run-smoke.sh`, `tests/run-kernel.sh`, `tests/run-transactional.sh`, `tests/run-independent-oracle.sh`, `tests/run-mixed-smoke.sh` and `tests/run-numerical.sh` when describing retained permanent suites.

Those literal root-level files are not present in the frozen scientific tree or the Status-A authority tree. They should be read as historical/umbrella suite labels, not as navigable executable paths.

For repository navigation, use the concrete permanent-testbank runners under `testbank/runners/`, the capability-specific test directories under `tests/`, and the immutable qualification/admission records named by the capability authority.

The historical release-readiness record itself is left unchanged: it is evidence of the decision made at that time. Current documentation corrects the navigation prospectively rather than rewriting that evidence.

## F-GC29 naming boundary

There are two uses of the label “F-GC29” in the repository history that must not be conflated.

The Status-A release-readiness narrative uses F-GC29 as an umbrella attribution for its same-tree residual/preservation reconciliation. Separately, `integration/f-gc/F-GC29_*` contains the Optional Groundwater Response Sensitivity Service Extension.

The second workunit is **not** the authority for general Status-A reference preservation. This page therefore grounds preservation claims in the release-readiness authority, F-SI33, F-TB11 and the specific capability evidence they name.

## Reviewer audit recipe

To audit a preservation claim:

1. identify the capability and its exact scientific/reference contract;
2. verify the pinned production/reference postimage;
3. follow the qualification and canonical-admission authority;
4. identify the stable preservation role or current-source replay protecting that capability;
5. check whether any relevant dependency changed after the evidence was produced;
6. if it did, require a new bounded replay/requalification rather than assuming inheritance.

This is stronger than asking only whether “the tests are green”, because it keeps the claim tied to what was actually tested and to the state that was actually qualified.

## Nonclaims

Reference preservation does not imply that:

- every possible SWAP 4.3.1 input produces bitwise-identical output in SWAP5;
- every historical model option belongs to the frozen Status-A denominator;
- one checksum proves all scientific state, flux and lifecycle semantics;
- old evidence automatically applies after a relevant dependency change;
- post-Status-A RossFast, application-composition or later coupling work belongs to the frozen review baseline;
- performance equality or speedup follows from scientific preservation;
- the separate F-GC29 response-sensitivity workunit is the umbrella preservation authority.

The preservation claim is deliberately narrower: **within the explicitly admitted and qualified Status-A capability boundaries, the recorded scientific/numerical contracts are protected by exact authority and dependency-aware replay.**
