# SWAP-009 full PDI production-path gate

Status: **PASS for the full-production and legacy-internal mass-balance gates**

This gate is intentionally separate from the earlier function-level PDI hydraulic test. It executes a complete SWAP 4.3.1 run through the ordinary soil-water solver, output and accounting paths.

## Case

The reproducible case is generated from the supplied B0 official `cases/2.grassgrowth` case by `make_case.py`.

The qualification case uses:

```text
period                1980-01-01 .. 1980-01-02
crop                  bare soil
initial h              -100000 cm, uniform
hydraulic model        8 (PDI), all five layers
SWVAPOR                1
Ksat layers 1-3        83.24164 cm/d
Ksat layers 4-5        25.81471 cm/d
bottom boundary        zero flux (SWBOTB=6)
reference ET           5.0 mm/d on both days
rain                   0
SWAFO                  2
CRITDEVMASBAL          1.0e-6 cm
```

The generated controlling input identities are:

```text
swap.swp  5de82558c539cbab0fe110c88d3509b25f689a781158c7b511a3f5086c549c7c
pdi.met   48c269785405464476ca49dd315e12ae67e782fb0e6d3cd0322155d0ab8fb3bc
```

## Builds

The full-run GNU compatibility build uses GNU Fortran 14.2.0 with runtime checking. Because the supplied TTUTIL and some source portability details require a GNU-compatible build preparation, this is not claimed to be a byte-identical Intel executable reproduction. The SWAP-009 target is separately anchored to the canonical B0 target hash and exact candidate target hash in the parent dossier.

Standard executable identities used here:

```text
B0        df2f6607bb268f28aae9ba43f6aa10807dc7d565a7405e83ba34f96381ac8417
candidate ba4670fa0ed445e8fe210a5fc090e4cbd10d4450e4a31fcba5abdf854c7225b4
```

Both standard runs completed normally and both followed exactly the same Newton histogram:

```text
2 iterations : 57 accepted solver steps
```

After generated timestamp normalization, the standard BFO results differ in one output record. Thus the complete production path observes the correction even without a diagnostic build.

## High-precision diagnostic build

`apply_output_diagnostics.py` is an output-only qualification transform applied identically to the B0 and candidate source trees. It:

- increases numeric precision for existing BFO `h`, `theta`, root-uptake and boundary-flux records;
- prints the already-computed unrounded `checkmassbal` ponding/profile/compartment residuals to stdout;
- changes no state, flux equation, constitutive equation, solver decision or timestep control.

After applying the identical diagnostic transform, the B0/candidate Fortran source trees differ only in `WC_K_models_04_11.f90`. The diagnostic build also retains the same 57 x 2-iteration Newton route as the standard build.

The high-precision production result shows an expected physical difference. Maximum pressure-head differences are:

```text
day 1: 0.0046007069 cm
day 2: 0.0032822287 cm
```

The corresponding maximum theta differences are about `4.92e-10` and `3.42e-10`. Boundary-flux output differs as well. These are small for the normal-Ksat case, as expected because liquid conductivity still dominates much of the profile at this suction; the earlier function-level gate separately demonstrates the much larger direct vapor-term effect as suction increases.

## Hard mass-balance gate for this legacy B1 qualification

The acceptance criterion was declared in the input before comparison:

```text
abs(residual) <= 1.0e-6 cm
```

The diagnostic exposes the existing unrounded legacy subsystem accounting. The maximum absolute combined ponding + profile residual was:

```text
B0        3.5598002490e-8 cm
candidate 3.5598034465e-8 cm
```

Maximum compartment residuals were at machine-precision scale (`<= 2.23e-16 cm`), and neither run created a `.dwb` deviation file. Both therefore pass the predeclared `1e-6 cm` gate by more than an order of magnitude.

This is hard, unrounded evidence for the **legacy B1 qualification case**. It must not be confused with the future B2 transaction-aware VQ mass-accounting contract: that separate contract remains required for SWAP5 reference/runtime qualification.

## Result

```text
full SWAP production execution       PASS
PDI vapor path active                PASS
normal B0/candidate completion       PASS
same normal-Ksat Newton route        PASS
observable expected B0/B1 difference PASS
unrounded legacy mass balance        PASS
```

Machine-readable evidence is in `evidence.json`.

This gate does not by itself admit SWAP-009. The repaired B1.5p1 VQ identity/reconstruction line must still be integrated, after which the corrected-reference bookkeeping can decide whether all admission gates are complete.
