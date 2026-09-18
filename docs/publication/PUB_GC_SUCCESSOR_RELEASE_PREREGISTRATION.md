# PUB-GC successor release authority preregistration

## Status

**PREREGISTERED — RELEASE IDENTIFIER / LICENCE AUTHORITY NOT YET ASSIGNED**

Date: 2026-09-18.

This record defines the bounded release-authority procedure for the SWAP5 version that will be cited by the PUB-GC GMD submission. It does **not** name or create the release.

## Predecessor authority

Immutable predecessor:

```text
release id:
SWAP5-RB1-v1

F-RB02 final authority commit:
b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0

authority:
release/f-rb02/F-RB02_CLOSEOUT.json
```

F-RB02 rule:

> SWAP5-RB1-v1 is immutable. Later integration/f-ci-canonical development does not alter RB1. A future release must enumerate its delta from RB1 and qualify its own candidate.

The PUB-GC release is therefore necessarily a **successor** release. RB1 may not be moved, retagged or reinterpreted.

## Required authority inputs before execution

Two external/governance values remain prerequisites:

```text
R1 = exact successor release identifier
L1 = exact SWAP5 publication-archive licence/redistribution statement
```

No release branch/tag/archive may be represented as publication-ready until both values are governed.

## Candidate-freeze rule

After R1 and L1 exist:

1. reconcile current `integration/f-ci-canonical`;
2. require all PUB-GC scientific, manuscript, prearchive and preservation gates green;
3. create one release-candidate branch from that exact canonical commit;
4. persist the candidate commit/tree and predecessor authority;
5. apply only release metadata/licence/archive changes that do not alter scientific or numerical semantics;
6. after those metadata changes, freeze one exact final release-authority postimage;
7. run exact-head release qualification on that postimage;
8. only a green exact-head postimage may receive R1.

A moving branch, earlier candidate or later canonical commit may not share the release identity.

## Required RB1-to-successor delta record

The successor release record must enumerate, at minimum:

- predecessor release ID and exact authority commit;
- common scientific ancestor / merge-base where relevant;
- current release candidate commit and tree;
- production-source delta classification;
- newly admitted application/coupling capabilities used by PUB-GC;
- qualification/preservation authorities added since RB1;
- publication evidence and reproduction assets added since RB1;
- explicit nonclaims and future-scope capabilities;
- licence/archive metadata delta.

The delta need not pretend that the current integration history is a linear continuation of the RB1 metadata branch. It must describe the scientific and repository-authority relationship honestly.

## Required qualification

The successor release exact-head gate must include, or inherit by explicit dependency proof:

- current F-CI canonical qualification;
- reference/scientific preservation gates required by current canonical;
- groundwater coupling preservation relevant to PUB-GC;
- E7 component-domain preservation;
- Documentation strict build;
- GMD prearchive integrity gate;
- exact publication-asset blob inventory;
- no unresolved publication-science claim drift;
- no release-metadata change to physics, solver, tolerances, transaction semantics or accepted scientific evidence.

If a production/dependency-sensitive delta occurs after qualification, only affected gates may be replayed by explicit dependency reasoning; the final release authority still requires a green exact-head closeout.

## Release identity semantics

R1 must be treated as an **opaque governed release identifier**, not an inferred claim about semantic-version compatibility.

Unless a separate version-policy authority says otherwise, the release name must not imply:

- complete SWAP 4.3.1 functionality;
- universal production completeness;
- universal MODFLOW coupling support;
- regional Hupsel validation;
- universal solver admissibility;
- Status AA;
- semantic-major/minor compatibility guarantees.

## Publication binding

Once exact-head release authority closes:

- GMD title uses the governed R1 value;
- Code/Data Availability cites the persistent archive of exactly that release;
- `PUB_GC_REPRODUCIBILITY_MANIFEST.json` records R1, exact commit/tree and DOI/PID;
- publication assets remain bound by their frozen evidence identities;
- development may continue afterward without altering the published release.

## Stop rules

Do not:

- reuse `SWAP5-RB1-v1`;
- choose R1 from this preregistration;
- assign a licence from this preregistration;
- create a publication archive before L1 permits redistribution;
- tag a candidate before exact-head release qualification;
- move the tag/release after publication;
- add science merely to make the release look broader.

## Closure

This preregistration closes the **procedure design** for A1.

The remaining A1 governance input is the exact successor release identifier/authority. After that input and L1 exist, the successor-release workunit is mechanical and qualification-gated.
