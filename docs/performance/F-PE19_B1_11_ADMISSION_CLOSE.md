# F-PE19 — SWAP-011 B1.11 admission closure

Date: 2026-09-16

Status: **WORK_BRANCH_CLOSED / CANONICAL_ADMISSION_PENDING**

## RECONCILE

F-PE19 was reconciled against live `integration/f-ci-canonical` head `5eb93542daf297d3aa89bee9552179387a7f2c68`. The intervening canonical M1-C4 serializer admission does not modify the SWAP 4.3.1 reference, SWAP-011 provenance, qualification evidence or B1 reconstruction dependencies.

## QUALIFY

Exact authorities:

- E7 upstream package SHA-256: `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac`
- historical E7 patch SHA-256: `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`
- ordered B1.10 -> B1.11 patch SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- exact B0 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested source archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`

The complete byte-safe replay reproduced B1.10 exactly and then reproduced the frozen B1.11 identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

Authoritative ordered target identities:

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

`SWAP/headcalc.f90` remains byte-identical to B0 at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## ADMIT

The F-PE19 work branch publishes B1.11 as B1.10 plus SWAP-011 only. It updates the immutable snapshot definition, ordered B1 manifest, human and machine-readable difference ledgers, provenance record and replay evidence. No SWAP5 production source is modified.

## CLOSE

Verdict: **SWAP-011 ADMISSION COMPLETE ON WORK BRANCH / READY FOR CANONICAL PR**.

Explicitly unchanged/excluded: no new physics, no mass-tolerance change, no solver/time-step-policy change, no SWAP-003 or SWAP-004 admission, no EB or RossFast scope, and no production-source mutation merely to obtain PASS.
