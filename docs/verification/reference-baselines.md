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

Historical B1.2-B1.5 remain recorded but fail exact provenance requirements. B1.5p1 repaired their intended five-fix identity and passed independent VQ qualification. B1.6 through B1.8 then admitted SWAP-009, SWAP-010 and SWAP-013 respectively.

The current corrected reference is **B1.9**:

```text
B1.9 = B0
     + SWAP-001
     + SWAP-005
     + SWAP-006
     + SWAP-007
     + SWAP-008
     + SWAP-009
     + SWAP-010
     + SWAP-013
     + SWAP-012
```

`SWAP-012` corrects the `prhead` inverse for hydraulic models 3 and 5-12. B0 applies the default unimodal MvG analytical inverse even when the selected retention relation differs. B1.9 instead inverts the actual selected retention relation using a robust bracketed/bisection path while leaving model 4 on its analytical default-MvG inverse.

The historical broad patch also contained SWAP-011 `dhconduc` work. B1.9 explicitly excludes that content and admits only the isolated inverse correction.

Qualification evidence:

```text
D2 affected-model round trips      22,240
B0 failures > 0.01 decade          17,176
corrected failures                 0
D2 max corrected error             2.09e-8 decade

isolated actual-source points      600
B0 failures @ 1e-6 decade          513
corrected failures                 0
max corrected error                1.17e-10 decade
```

Exact SWAP-012 identity:

```text
canonical B0 / ordered B1.8 MOD_MvG_functions.f90
a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

SWAP-012 fix.patch
263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131

corrected target
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
```

Deterministic B1.9 source identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

SWAP-012 changes no retention/conductivity equation, Richards residual/Jacobian, solver policy or mass-balance tolerance.

## B2: SWAP 5 reference mode

B2 is the full-accuracy SWAP 5 reference implementation. Verification records must state the exact B1 snapshot used as legacy-corrected oracle. The VQ-1d gate remains fail-closed because the repository still lacks the complete integrated callable B2 reference entrypoint/result surface needed for an honest B1 -> B2 numerical comparison.

A future release statement should therefore name the exact corrected reference, e.g.:

```text
SWAP 5 reference mode verified against
SWAP 4.3.1 Corrected Reference B1.9 (<exact manifest/commit>)
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

B1.9 is the current corrected legacy oracle. B2 comparison remains blocked until the integrated SWAP5 reference-mode seam satisfies the VQ-1d admission contract.
