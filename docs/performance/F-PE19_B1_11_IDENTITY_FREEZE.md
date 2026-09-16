# F-PE19 — B1.11 source identity freeze

Date: 2026-09-16

Status: `IDENTITY_FROZEN / FULL_REPLAY_VERIFIED / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

This checkpoint freezes the deterministic source-tree identity for B1.11. The originally pending mechanical replay gate has since completed successfully. Current closure authority is `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md` and machine-readable replay evidence is `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`.

## Predecessor

- snapshot: `B1.10`
- member count: `63`
- source bytes: `1,863,575`
- source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

## Qualified ordered admission transform

- SWAP-011 ordered patch SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes: `37,169`
- ordered preimage snapshot: `B1.10`
- historical E7 patch SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

The early identity-freeze checkpoint predated the exact full-distribution replay. Any different candidate postimage hashes in earlier revisions of this file are superseded draft metadata. The authoritative ordered identities reproduced by the byte-safe replay are:

```text
SWAP/MOD_MvG_functions.f90
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
-> 6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5

SWAP/WC_K_models_04_11.f90
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
-> e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874

SWAP/MOD_RIA.f90
a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
-> fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f
```

`SWAP/headcalc.f90` remains byte-identical at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## B1.11 identity

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

## Full replay closure

The exact outer SWAP 4.3.1 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` were replayed byte-safely through the qualified B1 predecessor chain and SWAP-011 ordered transform. The resulting B1.11 manifest matched the frozen identity above exactly.

The former state `ADMISSION_NOT_YET_MUTATED` is historical. The admission metadata is now present on the F-PE19 work branch. No SWAP5 production source, solver policy, mass tolerance or scientific formulation changed during closure.
