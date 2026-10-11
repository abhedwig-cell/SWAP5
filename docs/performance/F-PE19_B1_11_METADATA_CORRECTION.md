# F-PE19 — B1.11 admission metadata correction

Date: 2026-09-16

Status: `PASS`

During final consistency review, several draft governance documents were found to contain stale B1.11 target postimage hashes from an earlier text-normalized candidate path. Those hashes contradicted the byte-safe ordered applicator already stored in `reference/swap-4.3.1/patches/SWAP-011/apply_and_verify.py` and the exact replayed B1.11 source manifest.

No production source or admission patch bytes changed. The correction is metadata-only and binds every current authority to the byte-safe replay identities:

```text
MOD_MvG_functions.f90  6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104
WC_K_models_04_11.f90  d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126
MOD_RIA.f90            673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

The controlling B1.11 tree identity remains unchanged:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

This correction does not reopen scientific qualification. It repairs only inconsistent derived metadata before canonical admission.
