# SWAP-011 patch provenance gate

Status: **HISTORICAL_E7_RECOVERED / ORDERED_ADMISSION_TRANSFORM_PERSISTED / FULL_CANONICAL_REPLAY_PASS / ADMITTED_B1_11**

## Historical E7 authority

The exact qualified external artifact was recovered on 2026-09-16:

- package: `SWAP_4.3.1_E7_SW011_upstream_package.zip`
- recovered upload SHA-256: `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- internal historical `patch/SWAP-011_fix.patch` SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

The historical patch changes exactly:

```text
SWAP/MOD_MvG_functions.f90
SWAP/WC_K_models_04_11.f90
SWAP/MOD_RIA.f90
```

`SWAP/headcalc.f90` is unchanged.

The three historical B0 preimages match the canonical B0 member identities:

```text
MOD_MvG_functions.f90
  a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

WC_K_models_04_11.f90
  1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

MOD_RIA.f90
  a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
```

Historical E7 application was verified byte-safely, including the non-UTF-8 `MOD_RIA.f90`.

## Current ordered B1 admission transform

The historical E7 patch cannot be applied blindly to current B1 because later governance separately admitted overlapping/dependent corrections:

- SWAP-012 in `MOD_MvG_functions.f90`;
- SWAP-009 and SWAP-010 in `WC_K_models_04_11.f90`.

F-PE19 therefore derived a current-B1.10 ordered admission transform mechanically from exact byte authorities while preserving those admitted semantics. No implementation was reconstructed from prose.

Stored `fix.patch` in this directory is that **ordered admission transform**, not the historical E7 patch:

- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes: `37169`
- changed files: exactly the three files above.

Ordered B1.10 target preimages:

```text
MOD_MvG_functions.f90
  4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
WC_K_models_04_11.f90
  7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
MOD_RIA.f90
  a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
```

Authoritative ordered B1.11 postimages from the byte-safe full replay:

```text
MOD_MvG_functions.f90
  6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5
WC_K_models_04_11.f90
  e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874
MOD_RIA.f90
  fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f
```

These values supersede earlier draft postimage notes created before the complete canonical-distribution replay. The executable authority is `apply_and_verify.py` together with the full replay evidence and B1.11 snapshot.

## Qualification status

Historical E5/E6/E7 evidence remains immutable qualification of the exact historical E7 line.

F-PE19 additionally performed source-bound qualification of the composed B1.10 + SWAP-011 candidate. The current-B1 candidate passed the hydraulic testbank, focused vapor/RIA derivative gates and residual/constitutive invariance gates with no tolerance widening.

## Full canonical replay

The previously missing canonical distribution bytes were recovered and verified:

- outer SWAP 4.3.1 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- nested source archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

A complete byte-safe replay reconstructed the qualified predecessor chain through B1.10 and then applied the ordered SWAP-011 transform. It reproduced the frozen B1.11 identity exactly:

- member count: `63`;
- source bytes: `1,886,519`;
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

`SWAP/headcalc.f90` remained byte-identical at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

The former full-replay fail-closed gate is therefore resolved.

## Admission handling

SWAP-011 is admitted in B1.11. `reference/swap-4.3.1/b1-manifest.yml`, the B1.11 snapshot, the legacy-difference ledger and machine-readable expected-difference scope are updated together as one admission decision surface.

## Anti-reconstruction rule

The historical E7 implementation remains immutable and must never be reconstructed from descriptions. The current ordered admission transform is a separately identified mechanical composition whose provenance is explicitly bound to the recovered E7 bytes and already admitted B1 corrections.
