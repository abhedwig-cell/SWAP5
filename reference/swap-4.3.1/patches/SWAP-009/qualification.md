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

The candidate has been rerun through a direct Fortran harness using the canonical B0 module and the byte-verified corrected target.

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

Status:

```text
EXACT-CANDIDATE STRICT FORTRAN HYDRAULIC FUNCTION-LEVEL GATE: PASS
```

## Full PDI production-path regression

A second gate executes the complete SWAP solver rather than a function harness. The case is deterministically derived from the supplied B0 official `2.grassgrowth` case and uses:

```text
period             1980-01-01 .. 1980-01-02
crop               bare soil
initial h           -100000 cm uniform
hydraulic model     8 (PDI), all layers
SWVAPOR             1
Ksat layers 1-3     83.24164 cm/d
Ksat layers 4-5     25.81471 cm/d
bottom boundary     zero flux
reference ET        5.0 mm/d both days
rain                0
CRITDEVMASBAL       1.0e-6 cm
```

Controlling input identities:

```text
swap.swp  SHA-256 5de82558c539cbab0fe110c88d3509b25f689a781158c7b511a3f5086c549c7c
pdi.met   SHA-256 48c269785405464476ca49dd315e12ae67e782fb0e6d3cd0322155d0ab8fb3bc
```

The full-run GNU compatibility executables are:

```text
B0        df2f6607bb268f28aae9ba43f6aa10807dc7d565a7405e83ba34f96381ac8417
candidate ba4670fa0ed445e8fe210a5fc090e4cbd10d4450e4a31fcba5abdf854c7225b4
```

Both complete normally. Both have exactly the same nonlinear route:

```text
2 Newton iterations: 57 hits
```

The normal BFO files already contain one differing record after timestamp normalization. An identical output-only diagnostic transform was additionally applied to both source trees to expose existing `h`, `theta`, boundary-flux and `checkmassbal` values at higher precision. The diagnostic changes no state or physics expression, and after applying it the two Fortran source trees differ only in `WC_K_models_04_11.f90`. The diagnostic runs retain the same 57 x 2-iteration route.

Maximum high-precision pressure-head differences are:

```text
day 1  0.0046007069 cm
day 2  0.0032822287 cm
```

Maximum theta differences are approximately `4.92e-10` and `3.42e-10`; boundary-flux records also differ. This is the expected direction of evidence: the correction changes the active PDI vapor-conductivity path without changing the nonlinear route for this normal-Ksat case.

Status:

```text
REPRESENTATIVE FULL PDI PRODUCTION-PATH REGRESSION: PASS
```

## Hard water-balance evidence for the production case

The mass criterion was fixed in the input before comparison:

```text
CRITDEVMASBAL = 1.0e-6 cm
```

The diagnostic emits the already-computed unrounded legacy `checkmassbal` residuals. For the two reporting intervals, the maximum absolute combined ponding + profile residual is:

```text
B0        3.5598002490e-8 cm
candidate 3.5598034465e-8 cm
```

Maximum individual-compartment residuals are `<= 2.23e-16 cm`. Neither run creates a `.dwb` deviation file. Both therefore satisfy the predeclared `1e-6 cm` criterion by more than an order of magnitude.

This is hard, unrounded mass evidence for this **legacy B1 qualification case**. It does not replace the separate transaction-aware VQ accounting contract required for future B2/reference/runtime qualification.

Status:

```text
HARD FULL-RUN LEGACY MASS-BALANCE GATE: PASS
```

The reproducible case generator, output-only diagnostic transform and machine-readable evidence are under `tests/full-production/`.

## Qualification boundary

The SWAP-009 technical qualification is now complete through full production execution and hard legacy mass accounting. Formal B1 admission is still deliberately withheld until the repaired B1.5p1 independent VQ identity/reconstruction line is accepted/integrated. Once that dependency passes, corrected-reference bookkeeping may promote the expected difference and freeze a new immutable successor snapshot.

No tolerance relaxation is allowed for water balance, and this result does not create B1.6 by itself.

## Conclusion

```text
BUG_CONFIRMED: PASS
DIRECT CONSTITUTIVE CORRECTION: PASS
CANONICAL B0 PREIMAGE: PASS
EXACT STORED PATCH IDENTITY: PASS
AUDIT HYDRAULIC TEST EVIDENCE: PASS
EXACT-CANDIDATE STRICT FORTRAN HYDRAULIC GATE: PASS
FULL PDI PRODUCTION-PATH REGRESSION: PASS
HARD FULL-RUN LEGACY WATER BALANCE: PASS
CURRENT B1 BASE IDENTITY/RECONSTRUCTION: PENDING VQ INTEGRATION
B1 ADMISSION: PENDING
```
