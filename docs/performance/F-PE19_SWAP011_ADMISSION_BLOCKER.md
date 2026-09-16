# F-PE19 — SWAP-011 former admission blocker

Date: 2026-09-16

Status: `RESOLVED / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Protocol state: `RECONCILE = PASS -> QUALIFY = PASS -> ADMIT = PASS -> CLOSE = PASS_ON_WORK_BRANCH`

This document records the former natural state boundary at which F-PE19 was blocked only by the absence of the complete canonical B0 distribution. That blocker was subsequently resolved when the exact distribution bytes were supplied and verified.

## Former blocker

Formal B1 admission required an end-to-end reconstruction from the complete canonical B0 distribution rather than only the three affected target files. The controlling identities were:

- `SWAP_4.3.1.zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- nested Fortran source archive `SWAP.ZIP` SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The earlier checkpoint therefore correctly failed closed while those archive bytes were unavailable.

## Resolution

An exact duplicate of the canonical B0 distribution was supplied and its raw SHA-256 matched the controlling identity. `tools/vq/b1_11_reconstruct.py` was then run through the complete ordered reference chain and reproduced the frozen B1.11 identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The ordered SWAP-011 patch remains:

- SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`;
- byte count `37,169`;
- changed files exactly `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, `MOD_RIA.f90`.

The authoritative replayed target postimages are:

```text
MOD_MvG_functions.f90  6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5
WC_K_models_04_11.f90  e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874
MOD_RIA.f90            fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f
```

Any different target postimage hashes contained in earlier revisions of this blocker document are historical draft metadata and are superseded by the exact full-replay evidence.

## Current authority

The current closure records are:

- `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md`;
- `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`;
- `reference/swap-4.3.1/snapshots/B1.11.yml`;
- `reference/swap-4.3.1/b1-manifest.yml`.

SWAP-011 is now `ADMITTED_B1` on the F-PE19 work branch. Canonical repository admission still depends on the normal PR/CI/merge governance. No SWAP5 production source, physics, solver policy or mass tolerance changed during resolution.
