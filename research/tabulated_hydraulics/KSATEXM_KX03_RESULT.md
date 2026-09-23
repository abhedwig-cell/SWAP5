# TAB-HYD-KX03 — explicit analytical F-SI39 sub-branch result

Date: 2026-09-23

Status: **PASS_CONSTITUTIVE__READY_FOR_BOUNDED_REFERENCE_RICHARDS**

Controlling workflow run: `35858102782`.

## Candidate

The generated raw-head400 representation remains responsible for:

- returned theta;
- returned C;
- ordinary default-MvG K below the F-SI39 extension branch.

F-SI39 branch ownership is retained analytically:

1. reproduce the canonical default-MvG water-content operation ordering for branch authority only;
2. derive `Se_authority`;
3. apply the canonical strict `Se_authority > Se_threshold` predicate;
4. when active, compute K from the exact F-SI39 linear interpolation between `Kthr` and `KSATEXM`.

No solver policy, acceptance tolerance, table knot or physical state changed.

## Constitutive gate result

Exact Hupsel upper/lower parameter authority:

- global branch mismatches: **0**;
- local high-resolution branch mismatches: **0**;
- authority theta max difference versus canonical: **0**;
- authority Se max difference versus canonical: **0**;
- active F-SI39 K max abs difference: **0 cm/d**;
- active F-SI39 K max relative difference: **0**.

Generated representation fidelity outside the explicit extension branch:

- theta max abs = `6.694110871684894e-6`;
- C max abs = `2.5367137704370248e-5`;
- log10(K) max abs = `3.087089980411406e-4`.

Transition diagnostics:

- maximum K difference around the transition = `6.054170427205463e-7 cm/d`;
- local candidate continuity jump = `8.090202818777925e-8 cm/d`;
- active interpolation fraction range = `[6.683158721820171e-6, 0.9999999996883066]`;
- non-finite fractions = 0.

Canonical point oracles:

- saturated upper K = `832.4163 cm/d`, exact;
- saturated lower K = `227.6176 cm/d`, exact;
- lower h=-1 cm K = `153.81975964948481 cm/d`, exact;
- h=-5 cm extension-on/off difference = zero.

## Interpretation

KX03 resolves the F-TAB02-F constitutive scope conflict without approximating the admitted extension itself.

The acceleration representation remains an approximation only of the already-qualified base MvG constitutive relation. The F-SI39 KSATEXM extension is preserved as an explicit analytical sub-branch and is numerically identical to canonical authority over the tested exact Hupsel envelope.

This does not yet authorize production support. The next required gate is a bounded typed Reference-Richards K0 trajectory with the exact Hupsel KSATEXM parameter authority.

## Nonclaims

This result does not admit:

- F-TAB02-F production completion;
- whole-Hupsel application equivalence;
- generic SWSOPHY=1;
- arbitrary user tables;
- SWKIMPL=1;
- H_ENPR != 0 generated KSATEXM support;
- a portable speedup.
