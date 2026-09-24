# PUB-ME representative migration slices

Status: **prospectively frozen candidate set before detailed result extraction**

Publication owner: `PUB-ME`

Purpose: select the migration episodes that will be examined in detail for `PUB-ME` before numerical/result extraction, reducing the risk of choosing only clean or favorable examples after inspecting outcomes.

This document freezes the **candidate set**, not yet the final manuscript subset. A candidate may later be excluded only for a documented reason such as irrecoverable historical build state or overlap that makes it scientifically redundant. Exclusion may not be based merely on an unfavorable result.

## Selection criteria

The set must span distinct scientific-modernization risks:

1. hidden or ambiguous state ownership;
2. time/retry/acceptance ownership;
3. replaceable numerical service boundary;
4. persistence/restart authority;
5. longitudinal evidence invalidation after a legitimate later change.

The selected candidates are therefore intentionally heterogeneous.

## ME-S1 — Scientific state versus solver workspace ownership

Category: **state ownership migration**

Research relevance: H1, H2.

Current evidence anchors:

- `docs/numerics/richards-solver.md` documents the current separation between accepted start state, nonlinear candidate state and `mod_reference_richards_workspace` scratch;
- Status-A scientific production baseline `50346642bd565f79134ea17d5462e544b354998c` preserves the qualified post-migration state;
- F-TB11 / PR #111 includes Full Richards and solver-seam preservation in the permanent testbank.

Scientific risk represented:

- scratch or nonlinear candidate arrays accidentally becoming authoritative persistent state;
- hidden aliases changing later retries, worker isolation or solver substitution.

Historical authority state:

`AUTHORITY_RECOVERY_REQUIRED` for the exact earliest pre/post migration pair that most cleanly represents the state/workspace separation itself.

This candidate remains selected even if exact reconstruction later proves difficult; in that case it may become documentary/supporting evidence rather than a primary numerical pre/post slice.

## ME-S2 — Transactional interval and accepted-state ownership

Category: **time/retry/commit migration**

Research relevance: H1, H2, TS1.

Current evidence anchors:

- `docs/numerics/transactional-time-stepping.md`;
- F-TB11 / PR #111 records Kernel / Transactions / Generic Time / Mass v1 via F-KT19;
- stable preservation IDs include `FTB11-TXN-001`, `FTB11-MASS-001` and `FTB11-REJECT-001`;
- F-TA04 / PR #172 records the current bounded transaction/restart testbank traceability and preserves historical A23BL as historical rather than current mass-completeness authority.

Scientific risk represented:

- rejected candidate state entering scientific history;
- retry beginning from a mutated rather than accepted origin;
- mass/accounting authority becoming inconsistent with state authority.

Planned primary experiment:

- ME-E2 diagnostic candidate-state leakage fault injection;
- preservation/retry replay under normal transaction semantics.

Historical authority state:

F-KT19 is the capability authority named by F-TB11; exact pre/post migration commits still require authority reconstruction before ME-E1 historical reruns.

## ME-S3 — Mandatory typed soil-water solver seam / HeadCalc isolation

Category: **replaceable numerical service boundary**

Research relevance: H1, H3, H4, TS2.

Exact evidence anchors:

- F-SI35 canonical admission: PR #107;
- F-CI58P postimage reconciliation/preservation: PR #108;
- later semantic-successor preservation: F-CI93 / PR #157.

What the historical chain already records:

- one mandatory typed production solver seam;
- HeadCalc remains behind the compatibility boundary;
- standalone/worker paths use the typed seam;
- transaction/retry, hard mass, boundaries, diagnostics, sensitivity and isolation were part of preservation evidence;
- later legitimate composition changes required semantic requalification rather than blind hash replacement.

Scientific risk represented:

- architecture claims a solver seam while production still bypasses it;
- alternative numerical implementation changes model-level state/mass/acceptance ownership;
- stale exact-postimage evidence is mistaken for semantic authority.

Planned use:

- ME-E1 pre/post preservation slice where exact authorities can be reconstructed;
- ME-E6 extensibility example using later RossFast composition without importing `PUB-SQ` performance conclusions.

## ME-S4 — Restart as committed scientific continuation

Category: **persistence boundary migration**

Research relevance: H2, H3, TS1.

Current evidence anchors:

- F-TB11 / PR #111 records State / Persistence / Restart v1 via F-KT16 and stable ID `FTB11-RST-001`;
- F-DOC28 / PR #180 documents the frozen Restart v1 technical reference, including committed-state ownership, fail-closed restore gates and atomic publication boundary;
- F-TA04 / PR #172 records the pinned transaction/restart preservation chain.

Scientific risk represented:

- restart serializes insufficient accepted scientific state;
- restart accidentally depends on transient solver scratch;
- stale/cross-lineage restart restores incompatible state;
- split-run continuation diverges from continuous accepted trajectory.

Planned primary experiment:

- ME-E3 continuous versus split/restart continuation, including cases with and without retries before the restart point.

Historical authority state:

F-KT16 is the preserved capability authority named by F-TB11. Exact earliest implementation pre/post pair is optional for ME-E3 because the primary question can be tested prospectively on the admitted restart contract.

## ME-S5 — Semantic successor after legitimate composition change

Category: **longitudinal evidence invalidation/requalification**

Research relevance: H3, TS2.

Exact evidence anchors:

- F-KT21 accepted-trajectory directional sensitivity admission: F-CI75 / PR #143;
- research pre-integration smoke demonstrating old exact-blob preservation failures as evidence invalidation signals: PR #126;
- F-CI93 semantic-successor preservation: PR #157.

Key historical observation:

A legitimate later capability changed previously byte-locked composition surfaces. The old moving-preservation guards failed. Those failures were not automatically treated as a scientific defect and were not repaired by simply substituting new hashes. The affected semantic matrix was replayed before successor preservation authority was established.

Scientific risk represented:

- immutable historical evidence being incorrectly treated as moving-current authority;
- real scientific drift being hidden by mechanical hash updates;
- unrelated evidence being needlessly discarded after every change.

Planned primary experiment/analysis:

- ME-E4 Case B, semantic-successor evidence timeline;
- exact mapping of invalidated surface -> targeted replay -> successor authority.

This slice is deliberately retained because it includes a **failure signal**, not merely a clean successful migration.

## ME-S6 — Unrelated-change evidence reuse

Category: **longitudinal evidence preservation without replay**

Research relevance: H3.

Candidate evidence anchors:

- F-CI91 / PR #153 records a bounded RossFast preservation closeout where no relevant scientific dependency change required replay;
- multiple documentation-only/canonical deltas around later capabilities similarly preserve unchanged scientific dependency surfaces.

Scientific risk represented:

- unnecessary whole-model requalification after unrelated changes;
- inability to justify evidence reuse through explicit dependency boundaries.

Planned role:

- ME-E4 Case A, paired against ME-S5.

Final exact Case A authority will be frozen before result extraction after checking that the dependency relation is sufficiently simple to explain in a paper.

## Frozen candidate-set rule

The candidate set for detailed `PUB-ME` extraction is now:

```text
ME-S1 state/workspace ownership
ME-S2 transactional accepted-state ownership
ME-S3 typed solver seam / HeadCalc isolation
ME-S4 restart committed-state boundary
ME-S5 semantic successor after legitimate overlap
ME-S6 unrelated-change evidence reuse
```

The final manuscript need not present all six in equal depth.

At least four distinct categories must remain represented in the final evidence set, including:

- one direct behaviour-preservation migration;
- one adversarial accepted-state/retry experiment;
- restart/persistence;
- one longitudinal evidence invalidation/reuse pair.

## Next permitted actions

1. recover exact historical pre/post authorities for ME-S1, ME-S2 and ME-S3;
2. instantiate publication manifests for ME-E3 and ME-E4;
3. define the shared benchmark case set before executing detailed pre/post reruns;
4. design the qualification-only ME-E2 fault-injection harness without modifying production semantics.

Do not replace a difficult-to-reconstruct selected slice with an easier favorable slice without recording the reason and preserving this original selection record.
