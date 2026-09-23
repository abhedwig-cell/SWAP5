# TAB-HYD-KX06 — precomputed-boundary KSATEXM typed Richards result

Date: 2026-09-23

Status: **PASS_RESEARCH_HANDOFF_CANDIDATE**

Controlling runs:

- initial run: `35863794528`;
- independent repeat: `35863919254`.

Canonical authority: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

## Purpose

KX06 compares three constitutive routes in the same four-node typed Reference-Richards K0 harness used by KX04:

1. analytical F-SI39 authority;
2. KX03: raw-head generated provider plus analytical authority-state recomputation in the active KSATEXM branch;
3. KX05: raw-head generated provider plus immutable precomputed floating-equivalent branch boundary, with no analytical theta recomputation in the hot path.

Regimes:

- below threshold: h0=-5 cm;
- transition: h0=-2 cm;
- active extension: h0=-1 cm.

## Scientific result

Both KX03 and KX05 pass the existing KX04 scientific gates in both runs.

KX05 reproduces KX03's solver result to the reported precision:

| regime | max |dh| KX03 (cm) | max |dh| KX05 (cm) | max |dtheta| KX03 | max |dtheta| KX05 |
| --- | ---: | ---: | ---: | ---: |
| below threshold | 2.863e-9 | 2.863e-9 | 4.185e-11 | 4.185e-11 |
| transition | 7.199e-9 | 7.199e-9 | 3.358e-11 | 3.358e-11 |
| active extension | 4.585e-9 | 4.585e-9 | 7.025e-12 | 7.025e-12 |

Mass-residual differences remain of order `1e-17`.

Nonlinear-iteration counts and linear-solve counts are identical between analytical, KX03 and KX05 in all three regimes.

## Performance result

### Initial run `35863794528`

| regime | KX03 vs analytical | KX05 vs analytical | KX05 vs KX03 |
| --- | ---: | ---: | ---: |
| below threshold | -1.16% | **-25.48%** | **-24.60%** |
| transition | +8.42% | **-16.70%** | **-23.16%** |
| active extension | +24.23% | **-3.28%** | **-22.14%** |

### Independent repeat `35863919254`

| regime | KX03 vs analytical | KX05 vs analytical | KX05 vs KX03 |
| --- | ---: | ---: | ---: |
| below threshold | -2.17% | **-22.47%** | **-20.75%** |
| transition | +10.74% | **-13.90%** | **-22.25%** |
| active extension | +22.39% | **-2.93%** | **-20.69%** |

## Interpretation

KX03 established the correct scientific ownership boundary but paid for it by recomputing the analytical authority state on every active constitutive call.

KX05 preserves the same branch classification by converting the strict F-SI39 state predicate into immutable per-material floating-point pressure-head metadata at initialization.

The two independent KX06 runs show that this:

- preserves the KX03 scientific solution;
- preserves nonlinear and linear solver effort;
- removes roughly 20-24% of KX03 runtime in this four-node benchmark;
- restores at least slight acceleration even in the active KSATEXM extension regime.

The exact percentage is **not** a whole-Hupsel or production speed claim. The fixture is deliberately small and constitutive-heavy.

## Research decision

For generated default-MvG K0 acceleration with the exact Hupsel F-SI39 KSATEXM extension, KX05 supersedes KX03 as the preferred research implementation pattern:

- base raw-head400 generated provider;
- explicit wet theta/C and Ksat branch semantics;
- immutable per-material first-active KSATEXM pressure head derived from canonical authority at initialization;
- runtime F-SI39 interpolation fraction derived from generated theta;
- no tolerance-based branch ownership;
- no analytical authority recomputation in the repeated hot path.

KX03 remains the simpler scientific oracle/reference implementation for the extension branch.

No production source or canonical branch is modified by this result.
