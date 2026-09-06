# ADR-0005: Reference baseline chain for SWAP 5

Status: **Accepted**

Date: 2026-09-06

## Context

SWAP 5 is being reconstructed from SWAP 4.3.1 while the technical audit of 4.3.1 continues. During that work, genuine implementation defects can be discovered. Reproducing a proven legacy defect in SWAP 5 merely to obtain numerical equality with an uncorrected 4.3.1 build would turn a known bug into a new architecture requirement.

At the same time, the project must retain historical reproducibility: results produced by the original 4.3.1 baseline must remain explainable and reproducible.

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
6. a dedicated commit in the corrected-reference history.

B1 is a lineage. Immutable tags such as `B1.0`, `B1.1`, ... identify exact corrected snapshots. A moving `B1` tag is not used as a release oracle.

### B2: SWAP 5 reference implementation

B2 is SWAP 5 in full-accuracy `reference` mode. SWAP 5 is verified against an exact B1 tag or commit, not against an unspecified "latest corrected" state.

Where B1 deliberately differs from B0 because of an accepted bug fix, B2 is expected to reproduce B1 rather than the original B0 defect.

## Bug fix versus model change

A difference enters B1 only when it is a demonstrated implementation or numerical defect relative to the intended formulation.

A new or improved physical formulation is a model change, not a legacy bug fix. Such a change is qualified separately in SWAP 5 and does not silently redefine B1.

Documentation corrections likewise do not alter B1 numerical behaviour unless they expose a separate confirmed code defect.

## No bug-compatibility switches in the kernel

The SWAP 5 kernel will not contain switches whose purpose is to deliberately reproduce known B0 bugs. Historical reproduction belongs to B0. Compatibility adapters may preserve legacy input/output conventions, but they may not make a confirmed incorrect physical or numerical implementation part of the new kernel contract.

## Repository strategy

The intended repository split is:

```text
SWAP-4.3.1-reference
    B0 immutable baseline
    corrected-reference branch
    B1.0, B1.1, ... tags
    legacy regression and qualification tests

SWAP5
    new kernel and runtime
    SWAP 5 reference-mode tests
    documentation
    pinned reference to an exact B1 tag/commit
```

This prevents legacy implementation structure from becoming part of the SWAP 5 source tree while retaining a fully auditable comparison chain.

## Consequences

- Numerical equality with B0 is not, by itself, the definition of correctness for SWAP 5.
- Every accepted B0-to-B1 difference must be explainable from the difference ledger.
- SWAP 5 release evidence must state the exact B1 reference used.
- A new 4.3.1 defect discovered during migration first follows the audit/fix/qualification route before becoming a B1 correction.
- B0 remains available even after a bug is corrected in B1.

## Architecture invariants affected

This decision reinforces reference-before-optimization, explicit verification, separation of legacy compatibility from the kernel, and the rule that architecture changes are qualified rather than inferred from apparent output similarity.
