# TAB-HYD typed raw-head provider benchmark result

Date: 2026-09-23

Status: **qualified research evidence; no production admission**

## Question

Does the bounds-safe raw-head400 representation become materially cheaper when implemented behind SWAP5's existing vector-valued `constitutive_hydraulics_provider_t`, rather than through the legacy scalar `watcon/moiscap/hconduc` wrapper call pattern?

## Authority

The experiment was preregistered in:

- `research/tabulated_hydraulics/TYPED_PROVIDER_BENCHMARK_PREREGISTRATION.md`.

The original benchmark was bound to canonical:

- `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.

Live reconciliation on 2026-09-23 against:

- `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

showed identical blobs for the relevant execution seam:

- `mod_b110_default_mvg_provider.f90`: `90183cbe0f3f0b349e40fa6b0c65b2223ca8a739`;
- `mod_soil_water_solver_contract.f90`: `40a1ddc05fb8e2c1822763de645fd07a094568a3`;
- `mod_reference_richards_legacy_binding.f90`: `4b545c6fb260e81cd6c8f4d2d65f2beee7281e53`;
- `headcalc.f90`: `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`;
- `mod_b110_production_soil_water_task2.f90`: `0406d3180262b06a5a393b605cc553a912a26aa0`.

Therefore no relevant canonical dependency drift was found for this provider-level result.

## Candidate

Research-only provider:

- `research/tabulated_hydraulics/mod_tabhyd_raw_typed_provider_research.f90`.

It extends the existing production ABI and returns, in one vector call:

- theta;
- C;
- K;
- the reserved dK/dh output.

The benchmark did not alter the production Task-2 provider-selection policy.

Representation:

- 400 physical pressure-head knots per material;
- knot placement uniform in `log10(-h)`;
- raw `h` as runtime interpolation coordinate;
- `ln(K)` ordinate;
- explicit wet theta/C continuation;
- explicit Ksat plateau;
- preprocessing outside the timed evaluation loop;
- no per-evaluation allocation.

## Evidence

Workflow:

- `TAB-HYD typed raw-head provider benchmark`
- run `35535155474`
- conclusion: **success**.

All 30 Staring parameter rows in the source parameter set were included.

### Fidelity

Maximum sampled errors against the current analytical MvG provider:

| metric | maximum |
| --- | ---: |
| theta abs | `5.32098e-5` |
| C abs | `5.17194e-5` |
| log10(K) abs | `3.03816e-4` |

These are in the same small-error regime as the independent bounds-safe raw-head constitutive characterization.

### Performance

Eight balanced timing blocks:

| round | analytical (s) | table (s) |
| ---: | ---: | ---: |
| 1 | 0.261878 | 0.209455 |
| 2 | 0.261124 | 0.209032 |
| 3 | 0.259173 | 0.210048 |
| 4 | 0.259042 | 0.208905 |
| 5 | 0.259583 | 0.209075 |
| 6 | 0.259177 | 0.208780 |
| 7 | 0.259179 | 0.215948 |
| 8 | 0.258943 | 0.208327 |

Medians:

- analytical provider: `0.259178 s`;
- raw-head table provider: `0.2090535 s`;
- table delta: **`-19.3398%`**.

The reduction is present in every reported block and is much larger than the observed run-order/noise spread.

## Interpretation

This falsifies the earlier provisional interpretation that K0 tabulated hydraulics cannot accelerate the current admitted route.

The legacy scalar-wrapper whole-Hupsel experiments reached only parity because they evaluate constitutive functions through an unfavorable scalar/call-separated path. The current SWAP5 provider ABI already asks for theta, C and K together as vectors. That allows a table provider to amortize interval/data work and makes the constitutive kernel materially cheaper.

The correct current statement is therefore:

> **A bounds-safe raw-head400 table representation is approximately 19% cheaper than analytical MvG at the current SWAP5 vector-valued constitutive-provider boundary for the tested 30-material changing-head workload.**

This is **not** yet a claim of:

- 19% Reference-Richards solver speedup;
- 19% full SWAP application speedup;
- a portable speed guarantee;
- production admission.

## Next controlling gate

The preregistered second experiment is now required:

- inject the research provider through the existing request-level `constitutive_hydraulics_provider_t` seam;
- keep Reference Richards, K0, numerical tolerances and state ownership unchanged;
- test the bounded five-scenario hydraulic matrix;
- compare solver-state fidelity, mass diagnostics, nonlinear iteration counts and repeated runtime.

Only that integrated result can determine how much of the provider-level 19.3% survives the complete Reference-Richards solve.
