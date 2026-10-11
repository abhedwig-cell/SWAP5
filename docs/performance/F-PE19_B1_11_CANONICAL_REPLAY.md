# F-PE19 — canonical B0 full replay for B1.11

Date: 2026-09-16

Verdict: `PASS`

The supplied local archive `SWAP_4.3.1(1).zip` has SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, exactly matching the canonical SWAP 4.3.1 distribution. Its nested source archive `SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP` has SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The complete 63-member source was replayed through the qualified ordered B1 chain. B1.10 reproduced exactly at 1,863,575 bytes and manifest SHA-256 `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The persisted SWAP-011 ordered transform, SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`, was then applied byte-safely. The exact target transitions were:

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

The resulting B1.11 source tree reproduced the frozen identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

`SWAP/headcalc.f90` remained unchanged at SHA-256 `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

No production source was modified by performing this replay; it is qualification/evidence for B1 reference admission.
