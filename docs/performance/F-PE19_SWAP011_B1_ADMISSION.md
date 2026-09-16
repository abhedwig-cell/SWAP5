# F-PE19 — SWAP-011 current-B1 admission reconciliation

Date: 2026-09-16

Status: `RECONCILE_COMPLETE / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Protocol: `RECONCILE -> QUALIFY -> ADMIT -> CLOSE`

This document is the historical RECONCILE checkpoint for F-PE19. The workunit has since completed QUALIFY, exact full-B0 replay, ADMIT and CLOSE. The current authority is `docs/performance/F-PE19_B1_11_ADMISSION_CLOSE.md` together with `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json` and `reference/swap-4.3.1/snapshots/B1.11.yml`.

## Reconciliation result

The exact historical E7 package and patch were recovered and kept immutable:

- E7 upstream package SHA-256: `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- historical E7 patch SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`

Current B1.10 overlap was classified exactly:

- `MOD_MvG_functions.f90` already contains admitted SWAP-012 semantics;
- `WC_K_models_04_11.f90` already contains admitted SWAP-009 and SWAP-010 semantics;
- `MOD_RIA.f90` has no prior B1 correction.

A deterministic ordered B1.10 admission transform was derived from exact byte authorities without reconstructing implementation from prose. Its SHA-256 is `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238` and it changes exactly the three SWAP-011 target files.

## Final authoritative ordered identities

The early RECONCILE checkpoint predated the complete canonical-distribution replay. Any candidate postimage hash recorded in earlier revisions of this file is historical draft metadata and is **not** an admission authority. The exact full replay established these authoritative B1.10 -> B1.11 identities:

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

## Closure

The complete replay from exact B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` reproduced B1.11 exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The original RECONCILE conclusion `QUALIFICATION_REQUIRED` is therefore historical only. F-PE19 has progressed through QUALIFY and ADMIT on the work branch. No SWAP5 production source, physics, solver policy or mass tolerance was changed.
