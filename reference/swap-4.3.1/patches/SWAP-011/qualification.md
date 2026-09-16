# SWAP-011 qualification evidence

B1 admission status: **ADMITTED_B1 (B1.11)**

This page records the qualification completed in the SWAP 4.3.1 technical-audit line and the later exact-provenance/full-replay admission closure.

## Reference and final implementation progression

The audit first established a deliberately simple numerical-reference implementation that differentiates the actual active `K(h)` relation. This removed the derivative-consistency failures for the affected hydraulic models and served as a correctness oracle.

The production candidate was then optimized so the normal path did not pay for avoidable duplicate constitutive evaluations. The qualified final line uses model-specific/lazy constitutive state and preserves a finite-difference fallback only where needed for numerical/branch safety.

For the final qualified patch line, the production source changes are limited to:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

`headcalc.f90` remains byte-identical to B0 in that final line.

## E5 qualification gate

Recorded E5 evidence:

- 36/36 strict full SWAP runs passed;
- Newton iteration histograms/routes matched the qualified reference route exactly;
- `result.end` was byte-identical for the gate cases;
- direct focus included hydraulic models 3, 7, 10 and 12 plus 24 additional cases;
- measured runtime improvement versus the numerical-reference implementation was about 9.0% to 19.2%, with median about 12.3%;
- only the three source files listed above differed in the qualified patch tree.

This gate establishes that the optimized implementation did not gain performance by changing the solved physical problem or accepted nonlinear route for the tested scope.

## E6 broad D2-style qualification

Recorded E6 evidence:

- 150/150 runs completed normally;
- 60/60 D2/reference versus E5 Newton routes matched exactly;
- K0 `result.end`: 30/30 byte-identical;
- K1 `result.end`: 16/30 byte-identical;
- maximum reported H-RMSE: `1.43e-11 cm`;
- maximum reported nodal deviation: `9.98e-11 cm`;
- median E5/reference runtime ratio: `0.791`, about 20.9% faster;
- a 31/31 follow-up timing set was faster for the qualified implementation.

The non-byte-identical K1 cases remained at numerical round-off scale according to the reported state metrics, while the Newton route was unchanged.

## E7 upstream-package gate

The E7 step removed unused exploratory derivative wrappers, retained the lazy-state/fallback production route, and packaged the result for upstream transfer. Strict and optimized builds passed the E7 sanity checks; the focused model 3/7/10/12 routes retained exact Newton histograms and byte-identical `result.end` in the recorded sanity set.

The audit-line status after E7 was:

```text
FIX_TESTED
READY_PATCH_UPSTREAM
```

## Exact provenance and B1.11 replay closure

The historical E7 upstream package and exact patch were subsequently recovered. Their pinned identities are:

```text
E7 upstream package SHA-256
97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac

historical E7 patch SHA-256
9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110

ordered B1.10 admission patch SHA-256
1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238
```

A byte-safe replay was then performed from the exact SWAP 4.3.1 B0 distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, containing source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The replay reproduced the qualified B1.10 predecessor and the frozen B1.11 identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The ordered target postimages are:

```text
SWAP/MOD_MvG_functions.f90  6b65ce49904aa0c037d6f43f93115af7d35227b7f67d52dbdd96b614da955ab5
SWAP/WC_K_models_04_11.f90  e963989e81622cf0554aeeb6ecae705e20b41ff03e259e1b8753df0609884874
SWAP/MOD_RIA.f90            fe696bdf463259868ad3659072566babc8288ab1d8329bf068f8d3b5945a0d2f
```

`SWAP/headcalc.f90` remained byte-identical at `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`.

## B1 interpretation

SWAP-011 is a demonstrated legacy implementation defect with a qualified correction. Exact final E7 provenance and the ordered byte-safe replay gate are now both satisfied. SWAP-011 is therefore admitted as the sole new correction in B1.11.

## Invariants / constraints

- mass-conservation requirements and tolerances are unchanged;
- physical configuration is unchanged;
- the correction changes a Newton Jacobian derivative so that it is consistent with the residual's actual conductivity relation;
- model 4 remains the unaffected standard-MvG control;
- no performance policy or alternate physics is introduced;
- the B1.11 expected-difference envelope is limited to effects attributable to the corrected Jacobian derivative and its nonlinear convergence consequences.
