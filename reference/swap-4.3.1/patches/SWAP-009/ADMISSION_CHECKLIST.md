# SWAP-009 B1 admission checklist

Formal B1 admission is complete in snapshot `B1.6` once the admission PR carrying this checklist, the manifest and `B1.6.yml` is merged.

| Gate | Status |
| --- | --- |
| Stable audit ID | **PASS** |
| B0 defect classified as implementation bug | **PASS** |
| Intended Kelvin sign convention established | **PASS** |
| Minimal four-call-site correction isolated | **PASS** |
| Canonical B0 target SHA pinned | **PASS** |
| Exact stored `fix.patch` SHA measured after upload | **PASS** |
| Corrected target SHA pinned | **PASS** |
| Existing hydraulic/theory qualification recorded | **PASS** |
| Exact-candidate strict Fortran PDI hydraulic function-level gate | **PASS** |
| Repaired B1.5p1 base passes independent VQ identity/reconstruction/targeted gates | **PASS** |
| Representative full PDI production-path regression | **PASS** |
| Hard water-balance evidence for production-path regression | **PASS** |
| Expected-difference registry updated | **PASS** |
| Difference ledger promoted to `ADMITTED_B1` | **PASS** |
| Deterministic B1.6 source-tree identity pinned | **PASS** |
| New immutable B1 snapshot created | **PASS: B1.6** |
| Current B1 manifest includes ordered SWAP-009 patch | **PASS** |

## Admission identities

```text
predecessor                         B1.5p1
predecessor VQ oracle status        QUALIFIED_NUMERICAL_BEHAVIOURAL
new snapshot                        B1.6

SWAP-009 fix.patch SHA-256
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

canonical B0 WC_K_models_04_11.f90 SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

corrected WC_K_models_04_11.f90 SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7

B1.6 reconstructed source-tree manifest SHA-256
aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
```

## Qualification boundary

The function-level gate executes the actual PDI conductivity route. The full-production gate uses a reproducible two-day model-8 PDI case derived from the supplied official grass-growth case, with normal layer Ksat values, `SWVAPOR=1`, uniform `h=-1e5 cm`, zero bottom flux and `ETref=5 mm/d`.

Both B0 and the corrected run follow the same 57 x 2-iteration Newton route. The correction produces expected small state/flux differences. The predeclared unrounded legacy mass criterion is `1e-6 cm`; maximum absolute combined ponding + profile residuals are about `3.56e-8 cm` for both runs.

This qualifies the legacy correction for B1. It does not substitute for the future transaction-aware B2/VQ hard mass-accounting contract.

Current conclusion: **SWAP-009 is admitted as the sixth corrected-reference patch in immutable snapshot B1.6.**
