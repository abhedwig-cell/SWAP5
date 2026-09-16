# F-PE19 — prospective B1.11 source identity freeze

Date: 2026-09-16

Status: `IDENTITY_FROZEN / ADMISSION_NOT_YET_MUTATED`

This checkpoint freezes the deterministic source-tree identity that results from applying the exact qualified F-PE19 SWAP-011 current-B1 admission candidate to B1.10. It does not yet change `b1-manifest.yml` or publish B1.11.

## Predecessor

- snapshot: `B1.10`
- member count: `63`
- source bytes: `1,863,575`
- source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

The B1.10 identity was independently regenerated from the canonical B0 per-member manifest plus the exact already-admitted target postimages and reproduced the published B1.10 manifest SHA exactly.

## Qualified admission transform

Derived current-B1 SWAP-011 patch:

- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes: `37,169`
- ordered preimage snapshot: `B1.10`

Ordered target preimages:

- `MOD_MvG_functions.f90`: `4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1`
- `WC_K_models_04_11.f90`: `7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e`
- `MOD_RIA.f90`: `a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3`

Qualified candidate postimages:

- `MOD_MvG_functions.f90`: `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`, 48,883 bytes
- `WC_K_models_04_11.f90`: `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`, 30,043 bytes
- `MOD_RIA.f90`: `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`, 92,571 bytes

## Prospective B1.11 identity

The deterministic 63-member source manifest is stored at:

`docs/performance/evidence/F-PE19_B1_11_source_manifest.sha256`

Its cryptographic identity is:

- member count: `63`
- source bytes: `1,886,519`
- source manifest SHA-256: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

Unchanged files retain their exact B1.10 identities. Only the three qualified SWAP-011 target postimages differ.

`headcalc.f90` remains unchanged at B0/B1 identity `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## Freeze rule

These values are the only permitted B1.11 source identities for this admission candidate. If later reconstruction from the exact B0 archive plus ordered B1.10 patches and the stored SWAP-011 admission transform does not reproduce this manifest exactly, admission must fail closed.

The historical E7 patch is not this ordered admission transform. Historical E7 remains immutable at SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`.

## Remaining mechanical gate

Before publication of B1.11:

1. persist the exact 37,169-byte derived admission patch under the SWAP-011 dossier;
2. bind a byte-safe B1.10 applicator/reconstruction step to its SHA and the three ordered preimage/postimage identities;
3. reconstruct B1.11 from the canonical B0 source archive and require exact equality to the frozen manifest above;
4. only then update `b1-manifest.yml`, add the B1.11 snapshot and close the admission decision.

No production source, solver policy, mass tolerance or scientific formulation may change in completing these remaining mechanical gates.
