# SWAP-010 — model-7 capacity derivative

**Classification:** confirmed implementation/algebra bug  
**Target:** `SWAP/WC_K_models_04_11.f90`, function `C_MvG_2_s`  
**Admission target:** `B1.7`  
**Issue:** #37

Model 7 implements a scaled bimodal retention curve with one weighted common scaling denominator. The B1.6 capacity function instead applies separate unweighted component denominators and is therefore not the derivative of the implemented retention relation.

The correction is deliberately minimal: only the three model-7 capacity lines are changed. No retention function, conductivity relation, solver policy, tolerance or other hydraulic model is modified.

Because SWAP-009 already changes the same source file, SWAP-010 is order-sensitive. Canonical B0 remains the provenance origin, but the executable patch preimage is the exact B1.6 target after SWAP-009.

```text
canonical B0 target SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

ordered B1.6 preimage SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7

SWAP-010 corrected target SHA-256
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e

fix.patch SHA-256
f3d67771908e27a23610a650c4ad72813d882169f360a973472f86f545ee5deb
```

Qualification consists of a source-bound numerical-derivative gate and a representative full SWAP model-7 production-path run with unrounded water-balance diagnostics. See `qualification.md` and `tests/`.
