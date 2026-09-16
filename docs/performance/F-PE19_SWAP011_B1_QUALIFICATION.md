# F-PE19 — SWAP-011 current-B1 admission qualification

Date: 2026-09-16

Status: `QUALIFIED_FOR_B1_ADMISSION`

This qualification binds the exact F-PE19 current-B1 admission candidate derived during RECONCILE to fresh source-bound numerical evidence. It does not modify SWAP5 production source and does not replay or rewrite the historical E7 artifact.

## Candidate authority

Ordered preimage: corrected SWAP 4.3.1 `B1.10`.

Derived admission patch:

- SHA-256: `1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238`
- bytes: `37169`
- changed files: exactly `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90`, `MOD_RIA.f90`

Candidate postimages:

- `MOD_MvG_functions.f90`: `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104`
- `WC_K_models_04_11.f90`: `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`
- `MOD_RIA.f90`: `673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a`

The candidate is mechanically derived from exact historical E7 bytes plus the already admitted SWAP-009, SWAP-010 and SWAP-012 semantics. The historical E7 patch remains separately immutable at SHA-256 `9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110`.

## Toolchain

Fresh source-bound qualification used:

- GNU Fortran 14.2.0;
- compile flags: `-O2 -fPIC -ffree-line-length-none -fallow-argument-mismatch`;
- the unmodified hydraulic Fortran harness and Python runner recovered in `SWAP_4.3.1_complete_testbank.zip`;
- actual current-B1.10 target source and exact F-PE19 candidate source.

Both baseline and candidate hydraulic shared libraries compiled successfully. The historical harness was not edited to force execution.

## Unmodified hydraulic testbank

The recovered `hydraulic/python/run_tests.py` completed successfully for both B1.10 and the candidate.

For the current B1.10 baseline, the fraction of dK/dh cases with relative error greater than 1% is:

| model | B1.10 fail fraction | candidate fail fraction | candidate max relative error |
| ---: | ---: | ---: | ---: |
| 1 | 0 | 0 | 8.180445e-09 |
| 2 | 0 | 0 | 1.887918e-09 |
| 3 | 0.9801324503 | 0 | 6.991002e-09 |
| 4 | 0 | 0 | 8.612255e-09 |
| 5 | 0.1928934010 | 0 | 8.579920e-09 |
| 6 | 0.9873949580 | 0 | 7.941860e-09 |
| 7 | 0.9737991266 | 0 | 7.176805e-09 |
| 8 | 0.4454756381 | 0 | 5.667179e-06 |
| 9 | 0.5238095238 | 0 | 1.804897e-06 |
| 10 | 0.9748549323 | 0 | 6.479250e-07 |
| 11 | 0.9888888889 | 0 | 6.483029e-07 |
| 12 | 0.9976958525 | 0 | 9.900701e-09 |

The inverse/`prhead` failure fraction above 0.01 decade remains zero for all tested models for both B1.10 and the candidate. This directly confirms preservation of the already admitted SWAP-012 inverse behavior in the tested scope.

## Focused vapor-enabled dependency gate

Because SWAP-009 changed the signed-head vapor-conductivity dependency in the same module after historical E7, a fresh focused finite-difference gate was run for models 8-11 with vapor enabled over 100 randomized parameter sets per model.

| model | B1.10 n | B1.10 fail >1% | candidate n | candidate fail >1% | candidate max relative error |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 8 | 431 | 154 | 431 | 0 | 6.588361e-08 |
| 9 | 421 | 212 | 421 | 0 | 9.230644e-07 |
| 10 | 540 | 531 | 540 | 0 | 8.528939e-07 |
| 11 | 525 | 514 | 525 | 0 | 2.734491e-06 |

This specifically closes the model-10 vapor interaction identified during RECONCILE.

## RIA/model-12 focused gate

A separate 60-random-parameter-set model-12 derivative gate was run with vapor disabled and enabled.

| vapor | B1.10 n | B1.10 fail >1% | candidate n | candidate fail >1% | candidate max relative error |
| --- | ---: | ---: | ---: | ---: | ---: |
| off | 533 | 531 | 533 | 0 | 9.812848e-09 |
| on | 543 | 543 | 543 | 0 | 1.960329e-08 |

## Residual/constitutive invariance gate

A fresh broad comparison was run between current B1.10 and the F-PE19 candidate for observables that SWAP-011 is not intended to change: retention `theta(h)`, conductivity `K(h)`, capacity `C(h)` and inverse/`prhead` behavior.

The sweep covered all hydraulic models 1-12, both vapor states where applicable, and 10,920 evaluations per observable.

| observable | evaluations | bit-identical | max abs difference | max relative difference |
| --- | ---: | ---: | ---: | ---: |
| theta | 10,920 | 10,920 | 0 | 0 |
| K | 10,920 | 10,920 | 0 | 0 |
| C | 10,920 | 10,920 | 0 | 0 |
| inverse | 10,920 | 10,920 | 0 | 0 |

For model 12 specifically, 1,920 evaluations per observable across both vapor states were also bit-identical.

Therefore the candidate changes the intended Jacobian derivative behavior while preserving the tested residual/constitutive semantics, including admitted SWAP-009/SWAP-010/SWAP-012 behavior.

## Relationship to historical qualification

Historical E5/E6/E7 evidence remains the immutable qualification of the exact original E7 line: 36/36 E5 full runs, 150/150 E6 normal completions, 60/60 exact Newton-route comparisons, K0 30/30 byte-identical endpoints, round-off-scale K1 differences and focused E7 sanity.

The fresh F-PE19 qualification does not claim that those old runs were replayed. It independently qualifies the composed current-B1 candidate where later admitted dependencies differ from historical E7.

## QUALIFY verdict

`SOURCE_BUILD = PASS`

`UNMODIFIED_HYDRAULIC_TESTBANK = PASS`

`SWAP012_INVERSE_PRESERVATION = PASS`

`SWAP009_VAPOR_INTERACTION = PASS`

`RIA_MODEL12_VAPOR_OFF_ON = PASS`

`RESIDUAL_CONSTITUTIVE_INVARIANCE = PASS`

`TOLERANCE_WIDENING = NONE`

`PRODUCTION_SOURCE_CHANGE = NONE`

`QUALIFICATION_VERDICT = QUALIFIED_FOR_B1_ADMISSION`

## Next permitted action

Proceed to a mechanical B1.11 admission only after the exact derived admission patch is stored under the SWAP-011 candidate dossier and B1.11 reconstruction identity is frozen. The historical E7 patch must remain separately identified and unchanged.
