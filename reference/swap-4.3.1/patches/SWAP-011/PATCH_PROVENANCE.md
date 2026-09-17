# SWAP-011 patch provenance gate

Status: **HISTORICAL_E7_RECOVERED / ORDERED_ADMISSION_TRANSFORM_PERSISTED / FULL_CANONICAL_REPLAY_PASS / WORK_BRANCH_ADMITTED_B1_11**

## Historical E7 authority

Recovered exact external artifact:

- package `SWAP_4.3.1_E7_SW011_upstream_package.zip`
- package SHA-256 `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- historical `patch/SWAP-011_fix.patch` SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

The historical patch changes exactly `SWAP/MOD_MvG_functions.f90`, `SWAP/WC_K_models_04_11.f90` and `SWAP/MOD_RIA.f90`; `SWAP/headcalc.f90` is unchanged. Historical B0 target preimages match canonical B0, and application was verified byte-safely including non-UTF-8 `MOD_RIA.f90`.

## Ordered B1.10 admission transform

Current B1.10 already contains SWAP-012 in `MOD_MvG_functions.f90` and SWAP-009/SWAP-010 in `WC_K_models_04_11.f90`. F-PE19 therefore derived a separate mechanical ordered transform from exact byte authorities, without reconstructing implementation from prose.

Stored `fix.patch` SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`; bytes: `37,169`.

Authoritative ordered identities:

```text
MOD_MvG_functions.f90
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
-> 6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104

WC_K_models_04_11.f90
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
-> d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126

MOD_RIA.f90
a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
-> 673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

## Full canonical replay

Exact B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` were replayed through the full ordered chain.

B1.11 reproduced exactly:

- members `63`
- source bytes `1,886,519`
- source manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

The historical E7 artifact remains immutable provenance authority. The current ordered transform is separately identified and bound to exact predecessor identities and the full replay. Earlier draft target postimage hashes are superseded by the identities above.
