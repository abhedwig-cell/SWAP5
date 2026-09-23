# TAB-HYD-KX01 — KSATEXM theta-classified branch result

Date: 2026-09-23

Status: **FALSIFIED_STRICT_BRANCH_EQUALITY; INFORMATIVE**

Preregistration: `KSATEXM_PREREGISTRATION.md`.

Controlling runs:

- initial constitutive gate: `35857167689`;
- mismatch-location rerun: `35857343220`.

## Candidate

The qualified raw-head400 table representation supplied theta/C and the ordinary MvG K branch. F-SI39 activation was classified from generated-table relative saturation:

`Se_table > Se_threshold`.

Inside the active branch the exact admitted F-SI39 linear formula was used.

## Result

All quantitative fidelity checks were in the existing raw-head400 regime:

- theta max abs = `6.69411e-6`;
- C max abs = `2.53671e-5`;
- log10(K) max abs = `3.08709e-4`;
- active-branch K max abs = `1.32497e-2 cm/d`;
- active-branch K max relative = `5.82272e-5`;
- local transition K max abs = `9.58108e-6 cm/d`;
- local continuity jump = `1.60874e-8 cm/d`.

Canonical F-SI39 point oracles were preserved:

- saturated upper K = `832.4163 cm/d`;
- saturated lower K = `227.6176 cm/d`;
- lower-layer K at h=-1 cm = analytical `153.81975964948481`, candidate `153.81975999497510 cm/d`;
- below-threshold h=-5 cm analytical extension-on/off difference = zero.

The global logarithmic scan had zero branch-classification mismatches.

The preregistered high-resolution transition scan found exactly two mismatches in 20,002 node samples:

- upper layer: one mismatch;
- lower layer: one mismatch;
- both at `h=-1.9999999999999998 cm`;
- no mismatch at any other sampled head.

## Interpretation

The failure is the expected strict-equality sensitivity at the source transition, not a broad representational failure.

Legacy authority derives `Se_threshold` from the default-MvG relation at fixed `h=-2 cm`. For H_ENPR=0, analytical theta is monotone in h, so in exact arithmetic:

`Se > Se_threshold <=> h > -2 cm`.

The table theta differs from analytical theta by a few parts in 1e-6. At the floating representation immediately above -2 cm, that tiny interpolation difference can classify the table state on the opposite side of the strict `>` test.

KX01 is therefore not accepted because its branch identity is controlled by an approximated state variable at a discontinuous branch classifier.

## Next candidate

KX02 will preserve the source-defined strict head boundary directly:

`h > -2 cm`.

Within that branch it will still compute the F-SI39 interpolation fraction from generated-table theta/relative saturation, so quantitative table error remains exposed rather than hidden.

No tolerance is added and the equality case remains outside the extension branch.
