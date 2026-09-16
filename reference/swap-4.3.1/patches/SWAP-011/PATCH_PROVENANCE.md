# SWAP-011 patch provenance gate

Status: **HISTORICAL_E7_RECOVERED / ORDERED_ADMISSION_TRANSFORM_PERSISTED / FULL_CANONICAL_REPLAY_PENDING**

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

The three historical B0 preimages were independently reproduced from the recovered complete testbank and match the canonical B0 member identities:

```text
MOD_MvG_functions.f90
  a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

WC_K_models_04_11.f90
  1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

MOD_RIA.f90
  a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
```

Historical E7 application was verified byte-safely, including the non-UTF-8 `MOD_RIA.f90`, and reproduces the recovered E7 postimages after the line-ending convention documented by E7 is accounted for.

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

Qualified ordered postimages:

```text
MOD_MvG_functions.f90
  6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104
WC_K_models_04_11.f90
  d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126
MOD_RIA.f90
  673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

The exact ordered patch was materialized in GitHub Actions from deterministic transport chunks; the workflow checked both SHA-256 and byte count before committing it.

## Qualification status

Historical E5/E6/E7 evidence remains immutable qualification of the exact historical E7 line.

F-PE19 additionally performed fresh source-bound qualification of the composed B1.10 + SWAP-011 candidate. The current-B1 candidate passed the unmodified hydraulic testbank, focused vapor/RIA derivative gates and residual/constitutive invariance gates with no tolerance widening.

## Remaining fail-closed gate

Prospective B1.11 identity is frozen as:

- member count: `63`
- source bytes: `1,886,519`
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

`tools/vq/b1_11_reconstruct.py` reconstructs B1.10 from canonical B0 and then applies the exact ordered SWAP-011 transform. Formal admission requires that reconstruction to be executed against the canonical full B0 archive and to reproduce the frozen identity exactly.

Required canonical archive identity:

- supplied distribution `SWAP_4.3.1.zip`: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, or
- nested source archive `SWAP.ZIP`: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` where the reconstruction tooling accepts the controlling distribution input.

Those full archive bytes are not currently available in the accessible artifact set. Therefore `b1-manifest.yml` must remain unchanged and `SWAP-011` must not yet be marked `ADMITTED_B1`.

## Anti-reconstruction rule

The historical E7 implementation remains immutable and must never be reconstructed from descriptions. The current ordered admission transform is a separately identified mechanical composition whose provenance is explicitly bound to the recovered E7 bytes and already admitted B1 corrections.
