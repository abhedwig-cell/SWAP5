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
    B1.7.yml
    B1.8.yml
b1-manifest.yml
```

`b0/` is immutable. The canonical B0 source archive contains 63 Fortran members. `file-manifest.sha256` records the raw-byte SHA-256 and size of every member. Verification must operate on raw bytes; newline or encoding normalization is not allowed for B0 identity.

The Git connector is text-oriented and `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes. The archive hash and expanded-member manifest therefore remain the authoritative B0 identity until an unpacked tree has been imported through a binary-safe path and checked byte-for-byte.

## B1 representation

B1 is an ordered derivation rather than a duplicated source tree:

```text
B1.x = B0 + patch A + patch B + ...
```

Every admitted patch must have a stable audit ID, reproduced B0 defect, intended rule, minimal correction, exact stored patch identity, canonical B0 preimage identity and qualification evidence. When two patches touch the same source member, the later patch must additionally pin the exact ordered predecessor preimage; raw-B0 provenance alone is not sufficient.

Published snapshot files are immutable audit records. A later provenance defect is repaired by a new snapshot, never by rewriting the historical one.

## Current state

The corrected-reference lineage is:

```text
B1.0-bootstrap = B0
B1.1           = B0 + SWAP-001
B1.2           = B1.1 + SWAP-005
B1.3           = B1.2 + SWAP-006
B1.4           = B1.3 + SWAP-007
B1.5           = B1.4 + SWAP-008
B1.5p1         = same intended corrected source as B1.5, provenance repaired
B1.6           = B1.5p1 + SWAP-009
B1.7           = B1.6 + SWAP-010
B1.8           = B1.7 + SWAP-013
```

VQ-1c found that B1.2-B1.5 contain incorrect patch-artifact identity metadata and that the SWAP-007 dossier used a non-canonical B0 preimage hash. Those historical snapshots remain untouched and must not be used as exact executable oracles.

`B1.5p1` repaired those identities and subsequently passed VQ identity, deterministic reconstruction, broad control and all five predecessor correction-triggering gates. `B1.6` then admitted SWAP-009, the qualified PDI Kelvin-sign vapor-conductivity correction. `B1.7` added SWAP-010, the model-7 capacity-derivative consistency correction, including an explicit ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`.

`B1.8` adds SWAP-013, the PDI `HA/H0` input-domain guard. It rejects PDI model 8-11 inputs unless `0 < HA < H0` after the existing magnitude conversion. The accepted-input constitutive equations, solver policy, time integration and water-balance equations are unchanged. A source-bound strict Fortran gate passes 9/9 valid/invalid/non-PDI cases.

The current manifest therefore points to `B1.8` as the qualified numerical/behavioural corrected-reference oracle. Its deterministic source-tree identity is:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

Candidate directories may exist under `patches/` without affecting B1. SWAP-011, for example, remains `PATCH_PAYLOAD_PENDING` and is not part of B1.8.

## Boundary to SWAP 5

Production kernel/runtime code must not depend on implementation structures in this subtree. Reference-build and verification tooling may use it to reproduce B0 and construct qualified B1 snapshots.

B1 legacy mass evidence does not replace the future transaction-aware unrounded B2 mass-accounting gate. SWAP5 reference qualification remains fail-closed until the integrated B2 reference entrypoint and result contract exist.
