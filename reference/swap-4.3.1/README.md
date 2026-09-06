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
b1-manifest.yml
```

`b0/` is immutable after bootstrap. Do not edit a B0 payload or provenance record to represent a correction.

The canonical B0 source archive contains 63 Fortran members. `file-manifest.sha256` records the exact raw-byte SHA-256 and size of every expanded member, and `verify_source_archive.py` verifies both the complete archive and every member. The verifier must operate on raw bytes: newline or text-encoding normalization is not allowed for B0.

The current Git connector is text-oriented. Inspection found that `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes. Therefore the project deliberately does **not** claim that a text-normalized Git mirror is an exact B0 payload. See `b0/ENCODING_NOTES.md`. The archive hash and member manifest remain authoritative until an unpacked tree has been imported through a binary-safe path and checked byte-for-byte.

A B1 correction belongs under `patches/<audit-id>/` and must contain enough material to establish:

1. the reproduced B0 defect;
2. the intended formulation or implementation rule;
3. the minimal 4.3.1 correction;
4. regression/qualification evidence;
5. the expected B0-to-B1 behavioural difference.

Only after that gate passes may the patch be added to `b1-manifest.yml`.

## B1 representation

B1 is intentionally not maintained as a second full copy of the 4.3.1 source tree. It is defined as an ordered derivation:

```text
B1.x = B0 + patch A + patch B + ...
```

This makes every accepted deviation from official SWAP 4.3.1 directly auditable.

At initial bootstrap there are no admitted patches, so the current corrected reference is numerically identical to B0.

## Boundary to SWAP 5

Production kernel/runtime code must not depend on implementation structures in this subtree. Reference-build and verification tooling may use it to reproduce B0 and construct exact B1 snapshots.
