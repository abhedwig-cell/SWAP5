# Reference baselines

## Purpose

SWAP 5 verification uses an explicit B0 -> B1 -> B2 reference chain. Exact source identities use immutable hashes and snapshot identifiers; version labels alone are insufficient.

## B0: SWAP 4.3.1 audit baseline

B0 is the exact supplied SWAP 4.3.1 distribution used in the technical audit.

| Item | Value |
| --- | --- |
| Model | SWAP 4.3.1 |
| Release date stated by package | 2026-06-30 |
| Distribution SHA-256 | `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` |
| Source archive SHA-256 | `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` |
| Windows executable SHA-256 | `d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5` |
| Linux executable SHA-256 | `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862` |

The canonical source archive contains 63 Fortran members and 1,859,823 raw source bytes. `reference/swap-4.3.1/b0/file-manifest.sha256` is the authoritative expanded-source identity. `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes, so text-normalized Git copies cannot claim byte-exact B0 identity.

## B1: corrected SWAP 4.3.1 reference

B1 is a controlled ordered derivation:

```text
B1.x = B0 + ordered accepted patch set
```

Historical B1.2-B1.5 remain recorded but fail exact provenance requirements. B1.5p1 repaired their intended five-fix identity and passed independent VQ qualification. B1.6-B1.10 subsequently admitted SWAP-009, SWAP-010, SWAP-013, SWAP-012 and SWAP-002.

The current corrected reference is **B1.11**:

```text
B1.11 = B0
      + SWAP-001
      + SWAP-005
      + SWAP-006
      + SWAP-007
      + SWAP-008
      + SWAP-009
      + SWAP-010
      + SWAP-013
      + SWAP-012
      + SWAP-002
      + SWAP-004
```

`SWAP-004` corrects the tillage type-index mapping. B0 allocates the `iTT1/iTT2` lookup arrays by event count (`Ntill`) even though they are later indexed by `TYPE_TILLAGE`. A valid represented type code can therefore exceed the array extent. B1.11 allocates and maps over the type-code domain `1:tmax` and rejects an event type without corresponding `ITYPE_TILLAGE` entries.

Focused qualification evidence:

```text
B0 sparse represented type > Ntill       strict bounds failure reproduced
candidate dense legacy-valid mapping      unchanged
candidate represented type > Ntill        PASS
candidate non-contiguous represented type PASS
candidate missing mapping record          rejected
candidate total                           4/4 PASS
```

Exact SWAP-004 ordered identity:

```text
canonical B0 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

ordered B1.10 tillage.f90
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3

SWAP-004 fix.patch
0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818

B1.11 tillage.f90
41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede
```

Deterministic B1.11 source identity:

```text
members          63
source bytes      1,863,998
manifest SHA-256  a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6
```

The correction is intentionally limited to tillage lookup indexing and input consistency. SWAP-003 remains outside B1.11. No tillage constitutive equation, event timing rule, solver policy, timestep policy, water-balance equation or mass-balance tolerance changes. B0 has no standard complete tillage scenario, so this remains a focused qualification rather than an exhaustive tillage-module validation.

## B2: SWAP 5 reference mode

B2 is the full-accuracy SWAP 5 reference implementation. Verification records must state the exact B1 snapshot used as legacy-corrected oracle. The VQ-1d gate remains fail-closed because the repository still lacks the complete integrated callable B2 reference entrypoint/result surface needed for an honest B1 -> B2 numerical comparison.

A future release statement should therefore name the exact corrected reference, e.g.:

```text
SWAP 5 reference mode verified against
SWAP 4.3.1 Corrected Reference B1.11 (<exact manifest/commit>)
```

## Admission rule

```text
reproduce -> intended rule -> classify -> minimal patch
-> focused qualification -> exact provenance -> expected-difference ledger
-> immutable B1 snapshot -> SWAP5 verifies against corrected behaviour
```

Model development follows a separate qualification track and does not silently alter B1. When two admitted patches share a target, the later patch must pin the exact ordered predecessor preimage as well as canonical B0 provenance.

## Repository boundary

Production SWAP5 code must not depend on legacy implementation structures under `reference/swap-4.3.1/`. Only reference build, regression and qualification tooling may consume them.

## Current operational status

B1.11 is the current corrected legacy oracle. B2 comparison remains blocked until the integrated SWAP5 reference-mode seam satisfies the VQ-1d admission contract.
