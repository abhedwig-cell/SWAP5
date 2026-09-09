# F-CI19 — Qualified Candidate Convergence, Compatibility & Canonical Admission Planning

Status: `IN_PROGRESS_INVENTORY_AND_COMPATIBILITY_AUDIT`.

## Exact base

- Repository: `abhedwig-cell/SWAP5`
- Working branch: `integration/f-ci19-candidate-convergence`
- Immutable F-CI18 qualified closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- Qualified production-source head inherited from F-CI18: `da5026d8b87ad2f3c7912360891839a120ecccb6`
- F-CI18 remains the historical canonical-development-baseline qualification reference.

F-CI19 does not reopen F-CI18 qualification and does not treat the moving `integration/f-ci-canonical` branch head as a substitute for the immutable F-CI18 closeout commit.

## Purpose

F-CI19 converts the growing set of downstream qualified, partially qualified, experimental, superseded and blocked candidate branches into an explicit convergence model before any new canonical production admission.

The workunit must produce:

1. a machine-readable candidate graph with exact branch/head provenance;
2. explicit owner/dependency edges between candidates;
3. file-overlap and semantic-overlap classification;
4. compatibility decisions that distinguish independent composition from shared-semantics serialization;
5. a canonical admission plan that is fail-closed until all required owners and qualification evidence are present.

## Hard boundaries

- No blind merging of qualified branches.
- Qualification of a workunit does not imply compositional compatibility with another qualified workunit.
- Superseded branches are evidence nodes, not merge candidates.
- Characterization, readiness, feasibility and experimental branches are not production-admission candidates unless their own status explicitly permits that interpretation.
- Documentation-only governance changes remain separate from production qualification lineage.
- No production source, physics, numerical policy, state layout or transaction semantics are changed by the initial F-CI19 inventory phase.
- Hard mass conservation, rollback isolation, generic time, explicit owner boundaries and fail-closed reference semantics remain non-negotiable.

## Compatibility classes

Each candidate pair or dependency edge is classified as one of:

- `DISJOINT_COMPOSABLE`: no shared semantic owner and no conflicting source surface identified;
- `ORDERED_COMPOSABLE`: compatible only in a specified lineage/order;
- `SHARED_OWNER_SERIALIZE`: both touch one semantic owner; reconcile through the owner branch before composition;
- `EVIDENCE_ONLY`: useful qualification/evidence lineage but not a production merge candidate;
- `BLOCKED`: unresolved owner, qualification, numerical or physical blocker;
- `SUPERSEDED`: replaced by a later authoritative owner/candidate lineage;
- `UNKNOWN_FAIL_CLOSED`: insufficient live evidence; canonical admission prohibited.

## Canonical admission rule

A candidate may enter a future canonical admission sequence only when all of the following are true:

- exact branch/head is pinned;
- candidate status is production-admission compatible;
- all upstream owners are resolved;
- file overlap is inspected;
- semantic overlap is classified;
- required qualification workflows pass on the exact composition postimage;
- transaction and mass-conservation invariants remain hard gates;
- the admission order is recorded before merge;
- any unresolved ambiguity is treated as `UNKNOWN_FAIL_CLOSED`.

## Initial live findings

The first F-CI19 scan on 2026-09-09 already shows non-trivial convergence structure:

- `F-MR17` is explicitly superseded by `F-KT09` and `F-SI22` at head `411aa3097583145de0696bc6fcdca8e90d47165e`;
- `F-SI22` closes owner characterization but hands numeric-profile qualification downstream at head `1ac759b39ee743bfa0992d6b9da09f2cfeda38b9`;
- `F-VQ29` is still recording a finite-reference failure before calibration at head `1239650ea493f505fb250788e441f5656082bea3`;
- `F-GC02` remains tied to active F-SI20 owner evidence at head `9f5416835ad8f836f0ddd15778320d1e76108f70`;
- `F-LMFP09` remains in hydraulic-envelope characterization at head `bb91442ee5888a40398986c8d05df1972990955b`;
- `F-WOF25` has a qualified one-day evolution-readiness closeout at head `342096ca6d44a8d83458209eda2039424db0d2d5`, but readiness alone is not canonical-admission authority.

These findings are intentionally not converted into merge decisions yet.

## Phase structure

### CI19-A — authoritative inventory

Pin current family tips, exact heads, declared states, supersession and owner edges.

### CI19-B — overlap and compatibility audit

Compare candidate deltas against F-CI18 and against overlapping owner branches. Separate textual overlap from semantic ownership overlap.

### CI19-C — admission DAG

Produce the only permitted merge/admission order, with explicit holds for blocked or evidence-only nodes.

### CI19-D — composition qualification planning

Define exact postimage replay requirements before any canonical ref is advanced.

F-CI19 remains `IN_PROGRESS` until CI19-A through CI19-D are explicit and fail-closed.