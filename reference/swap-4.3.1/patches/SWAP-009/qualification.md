# SWAP-009 qualification evidence

Current B1 admission status: **CANDIDATE, NOT ADMITTED**

## Audit finding

The SWAP 4.3.1 issue register records SWAP-009 as:

```text
component: PDI hydraulics
category: code bug
status: FIX_TESTED
certainty: very high
severity: high
reproducible: yes
impact: large error in very dry soil conductivity
proposed fix: pass signed h to the vapor-conductivity helper
existing evidence: hydraulic tests and theory cross-check
```

## Independent constitutive reasoning

The B0 vapor helper uses a Kelvin relative-humidity term of the form:

```text
Hr = exp((h / 100) * MgRT)
```

where unsaturated pressure head `h` is negative. Passing `abs(h)` changes the exponent sign. That is inconsistent with the implemented formula and can give `Hr > 1` in unsaturated soil.

The four PDI conductivity functions are the affected callers. The minimal correction does not modify the helper itself and therefore preserves the shared Kelvin formulation for callers that already supply the correct sign.

## Recorded audit results

The earlier audit note reports, near 20 degrees C, the ratio between the old vapor term and the sign-corrected term as approximately:

```text
h = -1e5 cm   -> 1.16
h = -1e6 cm   -> 4.26
h = -1e7 cm   -> 1.99e6
```

This confirms that the defect becomes increasingly important in the very dry range for which PDI vapor/film processes are relevant.

## Exact B0 / corrected-source verification

The candidate patch is isolated to four identical caller substitutions in `WC_K_models_04_11.f90`.

```text
canonical B0 SHA-256:
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

number of B0 target occurrences:
4

stored fix.patch SHA-256:
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

corrected target SHA-256:
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
```

`apply_and_verify.py` fails closed on an unknown B0 preimage, requires exactly four substitutions and verifies the corrected target identity.

## Exact-candidate strict Fortran hydraulic gate

The candidate has now been rerun through a direct Fortran harness using the canonical B0 module and the byte-verified corrected target.

Compiler and runtime checks:

```text
GNU Fortran 14.2.0
-std=f2018 -ffree-line-length-none -O0 -fcheck=all
-ffpe-trap=invalid,zero,overflow -Wall -Wextra
```

The harness calls the actual `functionvalue_04_11` PDI model-8 route. For every head it evaluates the same state with vapor enabled and disabled and isolates:

```text
Kvap = K_with_vapor - K_without_vapor
```

At 20 degrees C:

| h [cm] | old/corrected `Kvap` | independent Kelvin ratio | relative discrepancy |
| ---: | ---: | ---: | ---: |
| -1e5 | 1.156064795222652 | 1.156064795196036 | 2.30e-11 |
| -1e6 | 4.264044823437194 | 4.264044823431949 | 1.23e-12 |
| -1e7 | 1987090.3453292965 | 1987090.3453166387 | 6.37e-12 |

At all three points:

```text
water-content difference old vs corrected = 0
K with vapor disabled difference          = 0
```

Thus the actual PDI conductivity call path reproduces the independent Kelvin sign prediction while the non-vapor PDI route remains unchanged in the tested scope.

Reproducible assets and machine-readable evidence are under:

```text
reference/swap-4.3.1/patches/SWAP-009/tests/
```

Status:

```text
EXACT-CANDIDATE STRICT FORTRAN HYDRAULIC FUNCTION-LEVEL GATE: PASS
```

## Qualification boundary

This result demonstrates the sign defect and direct constitutive correction through compiled Fortran, but it is still not a complete production qualification.

Before formal B1 admission, require:

- accepted/integrated independent VQ identity/reconstruction gate for the repaired B1.5p1 base;
- at least one representative full PDI SWAP production-path regression that actually exercises the vapor term;
- complete hard water-balance evidence for that run.

No tolerance relaxation is allowed for water balance. The physically active SWAP-009 correction remains outside B1 until these gates pass.

## Conclusion

```text
BUG_CONFIRMED: PASS
DIRECT CONSTITUTIVE CORRECTION: PASS
CANONICAL B0 PREIMAGE: PASS
EXACT STORED PATCH IDENTITY: PASS
AUDIT HYDRAULIC TEST EVIDENCE: PASS
EXACT-CANDIDATE STRICT FORTRAN HYDRAULIC GATE: PASS
CURRENT B1 BASE IDENTITY/RECONSTRUCTION: PENDING VQ INTEGRATION
FULL PDI PRODUCTION-PATH REGRESSION: PENDING
HARD FULL-RUN WATER BALANCE: PENDING
B1 ADMISSION: PENDING
```
