# Reference baselines

## Purpose

SWAP 5 verification uses an explicit B0 -> B1 -> B2 reference chain. Version names alone are not sufficient because the SWAP 4.3.1 development line and the audit can both evolve. Exact source identities therefore use immutable hashes and, once the corrected-reference repository exists, Git commits and tags.

## B0: SWAP 4.3.1 audit baseline

B0 is the exact supplied SWAP 4.3.1 distribution used as the baseline in the technical audit.

| Item | Value |
| --- | --- |
| Model | SWAP 4.3.1 |
| Release classification | development release |
| Release date stated by package | 2026-06-30 |
| Distribution archive | `SWAP_4.3.1.zip` |
| Distribution size | 8,959,314 bytes |
| Distribution SHA-256 | `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` |
| Fortran source archive | `tools/SWAP/source/SWAP.ZIP` |
| Source archive SHA-256 | `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` |
| Windows executable SHA-256 | `d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5` |
| Linux executable SHA-256 | `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862` |
| Package website | `https://swap.wur.nl/` |

The package `README_4.3.1.TXT` identifies version 4.3.1, release date 30 June 2026, Windows 11/Linux support, and the source location `tools/SWAP/source/`.

The cryptographic identity above is the controlling audit identity. If a development download later changes while retaining the same version label, it is not B0 unless its hash matches.

### Compiler provenance supplied with B0

The package compiler metadata records the Windows build as Intel Fortran Classic 2021.9.0, build 20230302_000000, with the supplied compiler option set in `tools/SWAP/compiler_settings/compiler_settings_4.3.1.txt`. The package also contains a Linux executable and a Linux compile/link script.

Compiler and executable identity are useful for reproduction, but B0 source identity is defined primarily by the distribution and source hashes above.

## B1: corrected SWAP 4.3.1 reference

B1 is not a replacement version label for SWAP 4.3.1. It is a controlled corrected-reference lineage derived from B0.

A change is admitted only after its bug classification, patch and qualification evidence are complete. The corrected-reference repository will use:

```text
baseline/B0                    exact B0 source
reference/4.3.1-corrected     B0 plus accepted fixes
B1.0, B1.1, ...               immutable corrected snapshots
```

Each B1 tag must resolve to one exact commit. Existing tags are never moved.

## B2: SWAP 5 reference mode

B2 is the full-accuracy SWAP 5 reference implementation. Verification records must state the exact B1 tag and commit used as the legacy-corrected oracle.

A SWAP 5 release must not merely claim "compatible with SWAP 4.3.1". The preferred statement is of the form:

```text
SWAP 5 reference mode verified against
SWAP 4.3.1 Corrected Reference B1.x (<commit>)
```

## Admission rule for a new legacy finding

A newly discovered legacy discrepancy follows this sequence:

```text
reproduce -> determine intended formulation -> classify

confirmed bug
    -> minimal 4.3.1 patch
    -> focused tests
    -> regression/qualification
    -> B1 commit
    -> immutable B1 snapshot when appropriate
    -> SWAP 5 verifies against corrected behaviour

model development
    -> separate design/qualification track
    -> no B1 change
```

## Current bootstrap status

The B0 cryptographic identity and B0/B1/B2 policy are recorded in the SWAP5 repository. The intended separate `SWAP-4.3.1-reference` repository is the home for the actual B0 source snapshot and B1 corrected history. Until that repository is created and seeded, no B1 tag is considered formally published.
