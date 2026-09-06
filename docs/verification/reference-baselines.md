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

Historical B1.2-B1.5 remain recorded but fail exact provenance requirements. B1.5p1 repaired their intended five-fix identity and passed independent VQ qualification. B1.6-B1.9 admitted SWAP-009, SWAP-010, SWAP-013 and SWAP-012.

The current corrected reference is **B1.10**:

```text
B1.10 = B0
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
```

`SWAP-002` corrects the tillage start-event initialization. In B0 the interval test in `set_iTill` compares the simulation start against the same event date as both lower and upper bound and can therefore never identify an interval between events. B1.10 sets `iTill` to the first event on or after the start, or `Ntill+1` after the final event, and loads the most recent previous tillage/consolidation parameters when applicable.

Qualification evidence:

```text
source-bound start cases           6
B0 passes                          3/6
corrected passes                   6/6
B0 failures                        between event 1/2, exact event 2, after final
corrected previous-event loading   PASS
```

Exact SWAP-002 identity:

```text
canonical B0 / ordered B1.9 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

SWAP-002 fix.patch
80e12cd4e9f47c192bd6c7d5ee7d460c473b3a2b29a5a553e8c35cf0b90b5c13

corrected target
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3
```

Deterministic B1.10 source identity:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

The correction is intentionally limited to `set_iTill`; SWAP-003 and SWAP-004 remain outside B1.10. No tillage constitutive equation, solver policy or mass-balance tolerance is changed. B0 has no standard full tillage scenario, so this admission is a focused start-state semantics qualification rather than an exhaustive tillage-module validation.

## B2: SWAP 5 reference mode

B2 is the full-accuracy SWAP 5 reference implementation. Verification records must state the exact B1 snapshot used as legacy-corrected oracle. The VQ-1d gate remains fail-closed because the repository still lacks the complete integrated callable B2 reference entrypoint/result surface needed for an honest B1 -> B2 numerical comparison.

A future release statement should therefore name the exact corrected reference, e.g.:

```text
SWAP 5 reference mode verified against
SWAP 4.3.1 Corrected Reference B1.10 (<exact manifest/commit>)
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

B1.10 is the current corrected legacy oracle. B2 comparison remains blocked until the integrated SWAP5 reference-mode seam satisfies the VQ-1d admission contract.
