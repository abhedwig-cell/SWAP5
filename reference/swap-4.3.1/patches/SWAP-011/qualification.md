# SWAP-011 qualification evidence

B1 admission status: **ADMITTED_B1 ON F-PE19 WORK BRANCH (B1.11); CANONICAL PR PENDING**

This page records the historical E5/E6/E7 qualification and the later exact-provenance/current-B1 admission qualification.

## Historical qualification

The audit established a numerical-reference derivative of the actual active `K(h)`, then optimized it to the final model-specific/lazy-state implementation with a bounded fallback route. Final changed production files were exactly:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

`headcalc.f90` remained byte-identical.

E5 recorded 36/36 strict full runs passing, exact Newton-route agreement and byte-identical `result.end` for the gate set. E6 recorded 150/150 normal completion, 60/60 exact Newton-route agreement, K0 30/30 byte-identical, K1 16/30 byte-identical with remaining differences at round-off scale, maximum H-RMSE `1.43e-11 cm`, maximum nodal deviation `9.98e-11 cm`, and a median E5/reference runtime ratio `0.791`. E7 removed unused exploratory wrappers and retained the qualified lazy-state/fallback route, ending at `FIX_TESTED / READY_PATCH_UPSTREAM`.

## Exact provenance

Recovered authorities:

```text
E7 upstream package SHA-256
97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac

historical E7 patch SHA-256
9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110

ordered B1.10 -> B1.11 patch SHA-256
1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238
```

The historical E7 patch was byte-verified against the exact B0 target preimages, including non-UTF-8 `MOD_RIA.f90`. Because current B1.10 already contains SWAP-009, SWAP-010 and SWAP-012 overlap, F-PE19 derived a separate mechanical ordered transform from exact byte authorities while preserving those admitted semantics.

## Current-B1 qualification and full replay

The ordered candidate passed fresh source-bound hydraulic derivative, inverse-preservation, vapor-interaction, RIA and non-derivative constitutive-invariance gates without tolerance widening.

Exact B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` were replayed through the complete ordered chain.

Authoritative ordered postimages:

```text
SWAP/MOD_MvG_functions.f90  6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104
SWAP/WC_K_models_04_11.f90  d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126
SWAP/MOD_RIA.f90            673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

B1.11 reproduced exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

`SWAP/headcalc.f90` remained byte-identical at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## Interpretation and invariants

SWAP-011 is a demonstrated legacy implementation defect: for implicit Richards solving, the Jacobian conductivity term must differentiate the actual conductivity relation used by the residual. The admitted difference envelope is limited to correcting that derivative for hydraulic models 3 and 5-12 and nonlinear-convergence consequences attributable to it. Model 4 remains the standard-MvG control.

Mass-conservation requirements and tolerances, physical retention/conductivity formulations, forcing, boundary definitions, solver policy and time-step policy are unchanged.
