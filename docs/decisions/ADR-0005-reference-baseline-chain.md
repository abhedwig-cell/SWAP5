# ADR-0005: Reference baseline chain for SWAP 5

Status: **Accepted**

Date: 2026-09-06

## Context

SWAP 5 is being reconstructed from SWAP 4.3.1 while the technical audit of 4.3.1 continues. During that work, genuine implementation defects can be discovered. Reproducing a proven legacy defect in SWAP 5 merely to obtain numerical equality with an uncorrected 4.3.1 build would turn a known bug into a new architecture requirement.

At the same time, the project must retain historical reproducibility: results produced by the original 4.3.1 baseline must remain explainable and reproducible.

The logical separation of the legacy references from the SWAP 5 kernel is mandatory. A separate Git repository is not mandatory. Keeping the reference material in the SWAP5 repository can simplify verification, CI and day-to-day work as long as the reference subtree remains explicitly isolated from production code.

## Decision

The project uses three explicit reference levels.

### B0: immutable SWAP 4.3.1 audit baseline

B0 is the exact SWAP 4.3.1 distribution supplied to and used by the technical audit. It is identified by cryptographic hashes, not by a mutable download URL or a version label alone.

B0 is never changed. Its purpose is historical reproduction and proof of the original behaviour.

### B1: corrected SWAP 4.3.1 reference line

B1 starts from B0 and contains only qualified corrections of demonstrated implementation or numerical defects. Each admitted correction must have:

1. a stable audit identifier;
2. a minimal legacy patch;
3. reproducible evidence of the defect;
4. regression and/or qualification tests;
5. a documented expected behavioural difference;
6. an auditable entry in the corrected-reference history.

B1 is a lineage. Exact corrected snapshots use immutable identifiers such as `B1.0`, `B1.1`, ... and, when represented by Git commits or tags, those identifiers are never moved.

Within the integrated repository, B1 is preferably represented as an ordered, qualified patch series applied to B0 rather than as a second full copy of the entire legacy source tree:

```text
B1.x = B0 + accepted patch 1 + accepted patch 2 + ...
```

This keeps the B0-to-B1 difference directly auditable.

### B2: SWAP 5 reference implementation

B2 is SWAP 5 in full-accuracy `reference` mode. SWAP 5 is verified against one exact B1 snapshot, not against an unspecified "latest corrected" state.

Where B1 deliberately differs from B0 because of an accepted bug fix, B2 is expected to reproduce B1 rather than the original B0 defect.

## Bug fix versus model change

A difference enters B1 only when it is a demonstrated implementation or numerical defect relative to the intended formulation.

A new or improved physical formulation is a model change, not a legacy bug fix. Such a change is qualified separately in SWAP 5 and does not silently redefine B1.

Documentation corrections likewise do not alter B1 numerical behaviour unless they expose a separate confirmed code defect.

## No bug-compatibility switches in the kernel

The SWAP 5 kernel will not contain switches whose purpose is to deliberately reproduce known B0 bugs. Historical reproduction belongs to B0. Compatibility adapters may preserve legacy input/output conventions, but they may not make a confirmed incorrect physical or numerical implementation part of the new kernel contract.

## Repository strategy

The accepted default is an isolated reference workspace inside the SWAP5 repository:

```text
SWAP5/
    reference/
        swap-4.3.1/
            b0/
                immutable B0 identity/source material
                provenance/
            patches/
                SWAP-xxx/
                    finding/evidence
                    minimal patch
                    qualification
            b1-manifest.yml
            README.md

    src/ ...
    docs/ ...
    tests/ ...
```

The rules are:

- `reference/swap-4.3.1/b0/` is immutable once its exact source identity is established;
- B1 is derived from B0 plus the ordered patch set declared in `b1-manifest.yml`;
- no SWAP 5 production code imports or depends on legacy implementation structure from this subtree;
- reference build/test tooling may read this subtree to construct B0/B1 executables or comparison runs;
- a later split into a dedicated `SWAP-4.3.1-reference` repository remains possible, but is an operational choice rather than an architecture requirement.

This keeps legacy implementation structure out of the SWAP 5 kernel while allowing one repository and one CI environment to own the complete verification chain.

## Consequences

- Numerical equality with B0 is not, by itself, the definition of correctness for SWAP 5.
- Every accepted B0-to-B1 difference must be explainable from the difference ledger and patch series.
- SWAP 5 release evidence must state the exact B1 snapshot used.
- A new 4.3.1 defect discovered during migration first follows the audit/fix/qualification route before becoming a B1 correction.
- B0 remains available even after a bug is corrected in B1.
- Logical reference isolation is mandatory; a separate Git repository is optional.

## Architecture invariants affected

This decision reinforces reference-before-optimization, explicit verification, separation of legacy compatibility from the kernel, and the rule that architecture changes are qualified rather than inferred from apparent output similarity.
