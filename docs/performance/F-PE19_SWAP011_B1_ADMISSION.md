# F-PE19 — SWAP-011 current-B1 admission reconciliation

Date: 2026-09-16

Status: `RECONCILE_COMPLETE / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Protocol: `RECONCILE -> QUALIFY -> ADMIT -> CLOSE`

The exact historical E7 package and patch were recovered and kept immutable:

- E7 package SHA-256 `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- historical E7 patch SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

Current B1.10 overlap was reconciled: SWAP-012 is already present in `MOD_MvG_functions.f90`; SWAP-009 and SWAP-010 are already present in `WC_K_models_04_11.f90`; `MOD_RIA.f90` has no previous B1 correction. A deterministic ordered transform was therefore derived from exact byte authorities without reconstructing implementation from prose.

Ordered patch SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`.

Authoritative B1.10 -> B1.11 target identities:

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

The complete replay from exact B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` reproduced B1.11 exactly at manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2` with 63 members and 1,886,519 source bytes.

Current authority is `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md`. No SWAP5 production source, physics, solver policy or mass tolerance was changed.
