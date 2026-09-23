# TAB-HYD-KX02 — source-head KSATEXM branch preregistration

Date: 2026-09-23

Status: **PREREGISTERED_RESEARCH_ONLY**

## Motivation

KX01 demonstrated that using generated-table theta to classify the strict F-SI39 branch causes exactly one classification mismatch per exact Hupsel layer, both at the floating representation immediately above the source transition h=-2 cm.

No other classification mismatch occurred and all quantitative constitutive errors stayed within the established raw-head400 regime.

## Authority

- current canonical: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- canonical F-SI39 implementation: `src/solver/mod_b110_default_mvg_provider.f90`;
- legacy parameter-construction authority: fixed `hthr=-2 cm` in ReadSwap, from which `relsatthr` and `Kthr` are derived;
- KX01 result: `KSATEXM_KX01_RESULT.md`.

For H_ENPR=0 default MvG theta is strictly monotone over the relevant unsaturated range. Since F-SI39's relative-saturation threshold is explicitly generated from h=-2 cm, the analytical source relation satisfies:

`relsat > relsatthr` if and only if `h > -2 cm`.

## Frozen KX02 candidate

Keep unchanged:

- 400 physical pressure-head knots;
- raw h interpolation coordinate;
- generated theta/C;
- generated ordinary-MvG ln(K) representation below the extension threshold;
- TSPACK preprocessing;
- exact F-SI39 linear extension formula.

Change only branch classification:

- KX01: `relsat_table > relsatthr`;
- KX02: `h > -2 cm`.

Inside the active branch use:

`f = (relsat_table-relsatthr)/(1-relsatthr)`

`K = f*KSATEXM + (1-f)*Kthr`.

Do not clamp f merely to make the test pass. If table theta yields an unacceptable negative or >1 interpolation fraction on a head-classified active point, the candidate fails.

At h=-2 cm exactly, the extension branch is inactive, matching the strict source semantics.

## Constitutive gate

Reuse the exact Hupsel upper/lower parameters and scans from KX01.

Required:

- zero candidate-vs-analytical branch classification mismatch in global and local scans;
- theta max abs <= 1e-4;
- C max abs <= 1e-4;
- log10(K) max abs <= 5e-4;
- saturated KSATEXM point oracles exact within 1e-9;
- lower h=-1 canonical oracle preserved;
- h=-5 extension remains exact no-op;
- local K continuity jump <= 1e-5 cm/d;
- all active-branch interpolation fractions finite;
- frozen numerical neighborhood: minimum f >= -1e-6 and maximum f <= 1+1e-12. No clamping is allowed.

No solver or acceptance tolerance may change.

## Decision rule

If the constitutive gate passes, proceed to a bounded typed Reference-Richards K0 trajectory using the exact two-layer Hupsel KSATEXM parameter authority.

Do not resume or modify F-TAB02-F until that solver-level research gate also passes.
