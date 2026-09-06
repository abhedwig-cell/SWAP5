# SWAP 4.3.1 reference workspace

This subtree contains the legacy reference material used to verify SWAP 5. It is deliberately isolated from SWAP 5 production code.

## Reference levels

- **B0** is the immutable SWAP 4.3.1 audit baseline.
- **B1** is B0 plus an ordered set of admitted, qualified legacy bug fixes.
- **B2** is SWAP 5 in full-accuracy `reference` mode.

## Layout

```text
b0/
    SOURCE_IDENTITY.md
    file-manifest.sha256
    verify_source_archive.py
    ENCODING_NOTES.md
patches/
    <audit-id>/
snapshots/
    B1.0-bootstrap.yml
    ...
    B1.5.yml
    B1.5p1.yml
b1-manifest.yml
```

`b0/` is immutable. The canonical B0 source archive contains 63 Fortran members. `file-manifest.sha256` records the raw-byte SHA-256 and size of every member. Verification must operate on raw bytes; newline or encoding normalization is not allowed for B0 identity.

The Git connector is text-oriented and `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes. The archive hash and expanded-member manifest therefore remain the authoritative B0 identity until an unpacked tree has been imported through a binary-safe path and checked byte-for-byte.

## B1 representation

B1 is an ordered derivation rather than a duplicated source tree:

```text
B1.x = B0 + patch A + patch B + ...
```

Every admitted patch must have a stable audit ID, reproduced B0 defect, intended rule, minimal correction, exact stored patch identity, canonical B0 preimage identity and qualification evidence.

Published snapshot files are immutable audit records. A later provenance defect is repaired by a new snapshot, never by rewriting the historical one.

## Current state

The intended correction lineage is:

```text
B1.0-bootstrap = B0
B1.1           = B0 + SWAP-001
B1.2           = B1.1 + SWAP-005
B1.3           = B1.2 + SWAP-006
B1.4           = B1.3 + SWAP-007
B1.5           = B1.4 + SWAP-008
B1.5p1         = same intended corrected source as B1.5, provenance repaired
```

VQ-1c found that B1.2-B1.5 contain incorrect patch-artifact identity metadata and that the SWAP-007 dossier used a non-canonical B0 preimage hash. Those historical snapshots remain untouched but must not be used as exact executable oracles.

`b1-manifest.yml` now points to `B1.5p1`. This new definition records the exact stored patch hashes and canonical B0 target hashes while preserving the same five intended corrections: `SWAP-001`, `SWAP-005`, `SWAP-006`, `SWAP-007`, `SWAP-008`.

Its status is deliberately `PENDING_VQ_IDENTITY_GATE`. It becomes the exact B1 oracle only after independent VQ repinning reports PASS. See `docs/verification/b1-5p1-provenance-repair.md`.

Candidate directories may exist under `patches/` without affecting B1. SWAP-011, for example, remains `PATCH_PAYLOAD_PENDING` and is not part of B1.5p1.

## Boundary to SWAP 5

Production kernel/runtime code must not depend on implementation structures in this subtree. Reference-build and verification tooling may use it to reproduce B0 and construct qualified B1 snapshots.
