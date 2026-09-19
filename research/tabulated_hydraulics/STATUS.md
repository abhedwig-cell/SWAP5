# TAB-HYD status: current tabulated soil hydraulics

Date: 2026-09-19

Scope: evidence-only characterization of the existing SWAP tabulated hydraulic-function route. This work does not admit new SWAP5 production physics.

## Authorities used

- Current public SWAP implementation: `SWAP-model/SWAP@c22bd832ddf3e53e330a552f5e31e74f183362d1`.
- Pre-strangler runtime used for executable legacy-input end-to-end tests: `SWAP-model/SWAP@2a5ace1c06be7a257b64e9ac1896b489533f16e9`.
- Hupsel case source: `SWAP-model/swap-testcases@a839e2e905f34dd264ad0c739f638454b3023def`.
- Current table core under test is the public `src/soil/sptabulated.f90` plus the public hydraulic wrappers, not a reimplementation.

## Findings

### 1. The interpolation core works well in its normal in-range regime

The complete preprocessing route, including the logarithmic transforms, lookup-bin construction, TSPACK preprocessing and the actual `EvalTabulatedFunction`, was run with bounds/runtime checks.

For a synthetic monotone Mualem-van Genuchten curve, the dense-grid characterization gave:

- maximum absolute theta error: `2.6145852e-7`;
- maximum absolute log10(K) error: `1.2071029e-5`;
- minimum C: `2.7105052e-27`, non-negative;
- minimum dK/dh: `6.8785279e-25`, non-negative.

A table-resolution sweep gave:

| points | max abs theta error | max abs log10(K) error |
| ---: | ---: | ---: |
| 25 | 1.68225e-3 | 5.06128e-3 |
| 50 | 5.93635e-5 | 2.10342e-4 |
| 100 | 4.10423e-6 | 1.23840e-5 |
| 200 | 1.48979e-6 | 1.21172e-5 |
| 400 | 6.18122e-7 | 1.19833e-5 |
| 800 | 1.99463e-7 | 1.19108e-5 |

This says that a very dense table is not automatically necessary for this smooth test function. Around 100 points, the conductivity interpolation error in this test is already close to the residual error floor of the current interpolation/transformation policy.

### 2. Representative published Staring tables behave regularly under the current interpolator

Six published BOFEK/Staring table files were sampled: B1, B9, B18, O1, O9 and O18. Each contains 459 rows.

At every interval midpoint tested:

- theta overshoot count = 0;
- K overshoot count = 0;
- C remained positive;
- dK/dh remained positive.

This is evidence that the current interpolation itself does not introduce obvious midpoint oscillation or loss of monotonicity for these representative tables. It is not yet an exhaustive audit of every Staring/BOFEK table.

### 3. The legacy-input table route is hydrologically faithful for Hupsel with SWKIMPL=0

A full 2002-2004 Hupsel run was executed with daily output for:

- analytical Mualem-van Genuchten hydraulics, `SWSOPHY=0, SWKIMPL=0`;
- generated equivalent tables, `SWSOPHY=1, SWKIMPL=0`.

Both completed normally with 1096 daily result rows. Differences were very small:

- GWL max absolute difference: `1.8e-4 cm`;
- GWL RMSE: `6.80e-6 cm`;
- DSTOR max absolute difference: `1e-5 cm`;
- rainfall, irrigation, runoff, drainage, QBOTTOM, EPOT, EACT, TPOT and TACT matched at the written output precision.

This is strong bounded evidence that the existing tabulated route can reproduce the analytical Hupsel response when the table is generated from the same constitutive functions and `SWKIMPL=0` is used.

### 4. The current implementation is not faster in the Hupsel control

A repeated full-period benchmark used ten alternating analytical/table runs after one warm-up per route.

- analytical median: `1.41755 s`;
- table median: `1.56812 s`;
- median table/analytical runtime ratio: `1.10597`;
- median table runtime delta: `+10.60%`.

So the present table implementation is about 11% slower in this case. This does not rule out a faster table design, fewer points, a different interpolation method, vectorization, caching, or a workload where constitutive evaluation dominates more strongly. It does rule out treating the existing table option itself as an already demonstrated acceleration.

### 5. SWKIMPL=1 is not qualified for the table route

For a 31-day Hupsel test:

- analytical `SWKIMPL=1` completed;
- tabulated `SWKIMPL=1` timed out after 20 s;
- the same tabulated case with only the saturated table derivative sentinel changed from `dK/dh = 1e8` to `0` completed in about 0.17 s.

The public wrapper explicitly returns `dK/dh = 1e8` when theta is within `1e-9` of the last tabulated theta. The executable diagnostic therefore identifies this sentinel as a direct cause of the observed table-route stall in this Hupsel experiment.

However, `SWKIMPL=1` itself is not a clean reference control in this pre-strangler runtime: the analytical `SWKIMPL=0` and `SWKIMPL=1` Hupsel runs show very large GWL differences. The table `SWKIMPL=1` route therefore remains **not qualified**, and the sentinel experiment must not be treated as a production fix or as proof of analytical/table equivalence under `SWKIMPL=1`.

### 6. A dry-side dK/dh bounds defect is reproducible

A direct call through the current public wrapper at a very dry pressure head (`h=-1e8 cm`) gives finite theta, C and K, but the dK/dh table evaluation reaches table index 0. With bounds checking this reproduces:

`Index '0' of dimension 3 of array 'sptab' below lower bound of 1`.

The dry-side derivative extrapolation therefore has a real bounds defect even though the theta and K extrapolation paths themselves remain finite in the same probe.

### 7. Current public typed production reachability

Source audit of `c22bd832...` already shows a capability gap:

- `soil.swsophy` accepts value 1;
- the typed soil schema has no table-file/table-data field corresponding to legacy `FILENAMESOPHY`;
- `config_to_variables` does not populate `numtablay`, `sptablay` or `ientrytablay`;
- `Initialize` explicitly zeros `numtablay` and `sptablay`;
- the `swsophy=1` branch in `soilhydraulics.f90` immediately consumes those arrays and indexes the final table entry via `numtab(node)`.

An executable current-public production-path probe is retained in the workflow and is being used to bind the exact runtime failure mode. Until that evidence is closed, `SWSOPHY=1` must not be considered a production-reachable capability of the current typed SWAP runtime.

## Current disposition

The table option is **not globally "broken"**, but neither is it currently safe to call it a generally working production option.

The bounded conclusion is:

1. the core table interpolation is numerically well behaved for the tested normal range and representative Staring tables;
2. the legacy-input route works very accurately for Hupsel with `SWKIMPL=0`;
3. the existing implementation is slower, not faster, in the repeated Hupsel benchmark;
4. the table route has a reproducible dry-side derivative bounds defect;
5. the `SWKIMPL=1` table route has a reproducible severe convergence/runtime defect associated with the saturated dK/dh sentinel and is not qualified;
6. the current public typed production input path does not yet provide the table data required by `SWSOPHY=1`.

No production admission or performance claim should be made until points 4-6 are resolved or explicitly excluded from the intended application envelope.
