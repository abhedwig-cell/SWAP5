# F-PE19 — SWAP-011 current-B1 admission qualification

Date: 2026-09-16

Status: `QUALIFIED_FOR_B1_ADMISSION / SUPERSEDED_BY_B1_11_ADMISSION_CLOSE`

Ordered preimage: corrected SWAP 4.3.1 `B1.10`.

Derived ordered admission patch:

- SHA-256 `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes `37,169`
- changed files exactly `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, `MOD_RIA.f90`

The exact historical E7 patch remains separately immutable at SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`.

Authoritative ordered postimages from the byte-safe replay are:

- `MOD_MvG_functions.f90`: `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`
- `WC_K_models_04_11.f90`: `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`
- `MOD_RIA.f90`: `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`

Fresh source-bound qualification used GNU Fortran 14.2.0 and the unmodified recovered hydraulic harness. The current-B1 candidate passed the hydraulic derivative testbank, preserved the admitted SWAP-012 inverse behavior, passed focused SWAP-009 vapor interaction and model-12/RIA vapor-off/on gates, and preserved non-derivative constitutive observables in the tested scope. No tolerance widening was used.

```text
SOURCE_BUILD                         PASS
UNMODIFIED_HYDRAULIC_TESTBANK       PASS
SWAP012_INVERSE_PRESERVATION        PASS
SWAP009_VAPOR_INTERACTION           PASS
RIA_MODEL12_VAPOR_OFF_ON            PASS
RESIDUAL_CONSTITUTIVE_INVARIANCE    PASS
TOLERANCE_WIDENING                  NONE
PRODUCTION_SOURCE_CHANGE            NONE
QUALIFICATION_VERDICT               QUALIFIED_FOR_B1_ADMISSION
```

The subsequent exact B0 -> B1.11 replay also passed, reproducing 63 members, 1,886,519 source bytes and manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
