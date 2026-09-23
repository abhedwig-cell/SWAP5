# TAB-HYD typed Reference Richards integration result

Date: 2026-09-23

Status: **qualified research evidence; no production admission**

## Research question

Does the bounds-safe raw-head400 table representation retain its provider-level performance advantage after it is injected through SWAP5's existing typed `constitutive_hydraulics_provider_t` seam into the current Reference Richards solver, while leaving solver equations, tolerances, state ownership and execution policy unchanged?

## Current-canonical authority

The integration workflow was rebound to:

- `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

The workflow explicitly checked that the relevant current-canonical blobs remained the same as in the preregistered provider experiment:

- analytical MvG provider: `90183cbe0f3f0b349e40fa6b0c65b2223ca8a739`;
- solver contract: `40a1ddc05fb8e2c1822763de645fd07a094568a3`;
- Reference Richards typed binding: `4b545c6fb260e81cd6c8f4d2d65f2beee7281e53`;
- HeadCalc: `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`.

No production Task-2 selection was changed. The research provider was supplied only through the existing request-level constitutive-provider pointer.

## Evidence

Workflow:

- `TAB-HYD typed Reference Richards integration`;
- run `35879637410`;
- job `107244454185`;
- conclusion: **success**.

Five bounded hydraulic cases were run through the current Reference Richards solver:

| scenario | max |Δh| (cm) | max |Δtheta| | analytical / table nonlinear iters | analytical median (s) | table median (s) | table delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| coarse_dry_free | 5.1524e-6 | 4.2787e-9 | 4 / 4 | 0.0021235 | 0.0014330 | **-32.52%** |
| loam_mid_free | 1.5237e-7 | 4.7539e-10 | 3 / 3 | 0.0017190 | 0.0012280 | **-28.56%** |
| clay_wet_free | 1.1611e-6 | 8.7980e-10 | 4 / 4 | 0.0021220 | 0.0014605 | **-31.17%** |
| coarse_dry_pulse | 7.8383e-6 | 5.3096e-9 | 4 / 4 | 0.0026850 | 0.0016280 | **-39.37%** |
| loam_capillary | 2.2837e-7 | 7.4690e-10 | 3 / 3 | 0.0017605 | 0.0012085 | **-31.35%** |

Additional observations:

- linear-solve counts were identical between analytical and table routes in every case;
- top-flux differences were zero at reported precision;
- prescribed-head bottom-flux difference in the capillary case was only `2.92e-9 cm/d`;
- integrated mass-residual differences were at approximately `1e-17 cm`;
- no solver-policy or convergence-tolerance change was introduced.

## Interpretation

This is substantially stronger than the legacy scalar-wrapper timing result.

The earlier legacy Hupsel K0 route reached only practical parity because it evaluated constitutive functions through separate scalar wrappers. Current SWAP5 already evaluates the constitutive relation through one vector-valued provider operation. Behind that seam:

1. provider-only evaluation was about **19.34% cheaper** than analytical MvG over the 30-material changing-head benchmark;
2. the four-node current-canonical Reference Richards fixture shows **28-39% lower repeated solve time** across all five bounded cases while preserving iteration counts and producing only microscopic state/mass differences.

The solver-level reduction being larger than the provider-only reduction is plausible for this small fixture because constitutive evaluation forms a large fraction of total solve cost and compiler/inlining/cache effects can differ between the two concrete providers. It must **not** be extrapolated directly to a full-size SWAP application.

## Scale limitation

The current integrated fixture has four soil nodes. Therefore the defensible current claim is:

> A raw-head400 table provider can materially accelerate the current typed K0 Reference Richards solver path in a small current-canonical fixture without changing the nonlinear trajectory class or accepted state within the tested envelope.

It is **not yet justified** to state a 28-39% production-wide, full-column or full-application speedup.

A 40-node repeat of the same provider swap has been preregistered/executed as the next scaling gate. That gate controls whether the acceleration survives when tridiagonal solve and other per-node solver costs become a larger fraction of total runtime.

## Production boundary remains unchanged

This result does not admit a new production provider.

A future production work unit would still need:

- deterministic typed table generation/ownership;
- explicit provider selection with analytical MvG retained as reference;
- current-application trajectory and preservation qualification;
- failure-closed table validation;
- transaction/restart proof that the provider carries no hidden physical state;
- independent performance evidence at application scale.

Generic user-supplied tabulated hydraulics remains a separate capability from a generated MvG-equivalent acceleration provider.
