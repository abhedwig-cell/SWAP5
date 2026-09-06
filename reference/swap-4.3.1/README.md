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
    B1.9.yml
b1-manifest.yml
```

`b0/` is immutable. The canonical B0 source archive contains 63 Fortran members. Raw-byte identity is controlled by the source-archive hash and `b0/file-manifest.sha256`; newline or encoding normalization is not allowed for B0 identity. `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes, so a text-only unpacked Git copy may not claim byte-exact B0 identity.

## B1 representation

B1 is an ordered derivation rather than a duplicated source tree:

```text
B1.x = B0 + patch A + patch B + ...
```

Every admitted patch must have a stable audit ID, reproduced B0 defect, intended rule, minimal correction, exact stored patch identity, canonical B0 preimage identity and qualification evidence. When patches share a source member, the later patch additionally pins the exact ordered predecessor preimage. Published snapshots are immutable audit records.

## Current state

```text
B1.0-bootstrap = B0
B1.1           = B0 + SWAP-001
B1.2           = B1.1 + SWAP-005
B1.3           = B1.2 + SWAP-006
B1.4           = B1.3 + SWAP-007
B1.5           = B1.4 + SWAP-008
B1.5p1         = same intended source as B1.5, provenance repaired
B1.6           = B1.5p1 + SWAP-009
B1.7           = B1.6 + SWAP-010
B1.8           = B1.7 + SWAP-013
B1.9           = B1.8 + SWAP-012
```

Historical B1.2-B1.5 contain provenance metadata defects discovered by VQ-1c and remain audit records rather than exact executable oracles. B1.5p1 repaired those identities and qualified the five predecessor corrections. B1.6 added the PDI Kelvin-sign correction; B1.7 added the model-7 capacity-derivative correction; B1.8 added the PDI `HA/H0` relational input guard.

`B1.9` adds only SWAP-012: `prhead` now inverts the actual selected retention relation for hydraulic models 3 and 5-12 rather than applying the unrelated default-MvG analytical inverse. The historical SWAP-011 `dhconduc` change that once shared a broad patch is explicitly excluded. A broad D2 qualification gives 0/22,240 corrected round-trip failures, and an isolated actual-source gate gives 0/600 failures versus 513/600 for B0 at `1e-6` decade tolerance.

The current corrected-reference identity is:

```text
snapshot         B1.9
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.9.

## Boundary to SWAP 5

Production kernel/runtime code must not depend on implementation structures in this subtree. Reference-build and verification tooling may use it to reproduce B0 and construct qualified B1 snapshots.

Legacy B1 evidence does not replace the transaction-aware unrounded B2 mass-accounting gate. SWAP5 reference qualification remains fail-closed until the integrated B2 reference entrypoint and result contract exist.
