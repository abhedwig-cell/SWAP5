# SWAP-009 targeted PDI hydraulic gate

This directory contains a reproducible Fortran function-level qualification of the exact SWAP-009 candidate.

It is deliberately narrower than a full SWAP regression. The purpose is to prove that the stored candidate changes the actual PDI vapor-conductivity execution path exactly as predicted by the Kelvin relation, while leaving water retention and the no-vapor conductivity path unchanged.

## Inputs and identity

The gate requires the byte-exact B0 member:

```text
SWAP/WC_K_models_04_11.f90
SHA-256 1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd
```

The existing dossier `apply_and_verify.py` materializes the candidate and requires:

```text
stored fix.patch SHA-256
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

corrected target SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
```

The four substitutions are therefore tied to the canonical B0 preimage before compilation.

## Test method

`pdi_harness.f90` executes hydraulic model 8 through `functionvalue_04_11` at:

```text
h = -1e5, -1e6, -1e7 cm
T = 20 deg C
```

For each head it evaluates the same PDI state twice:

```text
K_with_vapor
K_without_vapor
```

and isolates:

```text
Kvap = K_with_vapor - K_without_vapor
```

This makes the test sensitive to the actual PDI conductivity caller path while keeping the other PDI conductivity components in the calculation.

The expected old/corrected vapor ratio is independently calculated from the sign change in the Kelvin term:

```text
exp( 2 |h| / 100 * MgRT )
```

The gate also requires exactly zero old-versus-corrected difference in:

- water content `WC(h)`;
- conductivity with vapor disabled.

Thus the candidate must affect only the intended vapor contribution in this targeted scope.

## Reproduction

With GNU Fortran available:

```text
python reference/swap-4.3.1/patches/SWAP-009/tests/run_hydraulic_gate.py \
    /path/to/exact/B0/WC_K_models_04_11.f90 \
    --output swap009-hydraulic-result.json
```

The recorded run used GNU Fortran 14.2.0 with strict bounds/runtime and floating-point trapping. See `result_gfortran14_2.json`.

## Recorded result

The direct vapor-term ratios were:

| h [cm] | old/corrected Kvap | independent Kelvin ratio |
| ---: | ---: | ---: |
| -1e5 | 1.156064795222652 | 1.156064795196036 |
| -1e6 | 4.264044823437194 | 4.264044823431949 |
| -1e7 | 1987090.3453292965 | 1987090.3453166387 |

Maximum relative ratio discrepancy is below `2.4e-11`, comfortably inside the gate tolerance `1e-9`.

At all three points:

```text
WC old - corrected        = 0
K(no vapor) old-corrected = 0
```

Status:

```text
SWAP-009 targeted hydraulic function-level gate = PASS
```

## Qualification boundary

This result does not admit SWAP-009 to B1 and does not replace the remaining production evidence.

Still required:

- accepted B1.5p1 VQ identity/reconstruction base;
- at least one representative full SWAP PDI run that activates the vapor path;
- hard water-balance evidence for that full run.

No water-balance tolerance is relaxed by this gate.
