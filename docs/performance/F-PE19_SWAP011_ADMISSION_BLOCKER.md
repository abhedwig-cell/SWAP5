# F-PE19 — SWAP-011 former admission blocker

Date: 2026-09-16

Status: `RESOLVED / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Protocol state: `RECONCILE = PASS -> QUALIFY = PASS -> ADMIT = PASS_ON_WORK_BRANCH -> CLOSE = PASS_ON_WORK_BRANCH`

The former blocker was the absence of the complete canonical B0 distribution. That blocker is resolved: the supplied duplicate distribution matches SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, and its nested `SWAP.ZIP` matches `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The exact ordered replay reproduced B1.10 and then B1.11:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

Authoritative B1.10 -> B1.11 target postimages are:

```text
MOD_MvG_functions.f90  6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104
WC_K_models_04_11.f90  d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126
MOD_RIA.f90            673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

Any earlier draft postimage hashes are superseded. Current authority is `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md`, `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`, `reference/swap-4.3.1/snapshots/B1.11.yml`, and `reference/swap-4.3.1/b1-manifest.yml`.

No SWAP5 production source, scientific formulation, solver policy or mass tolerance changed in resolving the blocker.
