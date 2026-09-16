# F-PE19 — SWAP-011 B1.11 admission closure

Status: **ADMISSION_READY / QUALIFICATION PASS**

## RECONCILE

F-PE19 was reconciled against live `integration/f-ci-canonical` head `5eb93542daf297d3aa89bee9552179387a7f2c68`. The intervening canonical changes were confined to M1-C4 output-serialization admission files and did not modify the SWAP 4.3.1 reference, SWAP-011 provenance, qualification evidence or B1 reconstruction dependencies.

## QUALIFY

The exact historical SWAP-011 E7 artifact is recovered and pinned:

- E7 upstream package SHA-256: `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- historical E7 patch SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`
- ordered B1.10 admission patch SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`

The complete byte-safe replay used exact B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, containing exact source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The replay reproduced B1.10 exactly and then produced the frozen B1.11 source identity:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

Target postimages:

```text
SWAP/MOD_MvG_functions.f90  6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5
SWAP/WC_K_models_04_11.f90  e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874
SWAP/MOD_RIA.f90            fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f
```

`SWAP/headcalc.f90` remained byte-identical to B0 at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

Detailed machine-readable replay evidence is stored in `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`.

## ADMIT

The admission decision surface is now satisfied. B1.11 is defined as B1.10 plus SWAP-011 only. The admission updates:

- `reference/swap-4.3.1/snapshots/B1.11.yml`;
- `reference/swap-4.3.1/b1-manifest.yml`;
- `reference/swap-4.3.1/README.md`;
- `docs/verification/legacy-differences.md`;
- `docs/verification/expected-differences.json`;
- SWAP-011 finding and qualification status.

No SWAP5 production source is modified by this admission.

## CLOSE

Verdict: **SWAP-011 QUALIFIED FOR B1.11 ADMISSION**.

The former `PATCH_PAYLOAD_PENDING` provenance gate is resolved. The current corrected SWAP 4.3.1 reference becomes B1.11 once this admission commit is accepted into canonical governance.

Explicitly unchanged/excluded:

- no new physics;
- no mass-tolerance change;
- no time-step-policy change;
- no SWAP-003 or SWAP-004 admission;
- no production optimization beyond the historically qualified E7 implementation;
- no SWAP5 production-source mutation.
