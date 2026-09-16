# F-PE19 — B1.11 source identity freeze

Date: 2026-09-16

Status: `IDENTITY_FROZEN / FULL_REPLAY_VERIFIED / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Predecessor B1.10 identity:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

Ordered SWAP-011 admission transform:

- SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes `37,169`
- historical E7 patch SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

Authoritative byte-safe ordered identities:

```text
SWAP/MOD_MvG_functions.f90
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
-> 6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104

SWAP/WC_K_models_04_11.f90
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
-> d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126

SWAP/MOD_RIA.f90
a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
-> 673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

`SWAP/headcalc.f90` remains byte-identical at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

Frozen and replay-verified B1.11 identity:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The exact outer distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` were replayed through the complete ordered chain. Earlier draft target postimage hashes are superseded by the values above.
