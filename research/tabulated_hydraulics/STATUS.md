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

### 2. The 36-file BOFEK2012/Staring set exposes one input-table defect

The complete public BOFEK2012/Staring table set in `Murilodsv/SWAP-SAMUCA` was checked against the admission rules implemented by current `ReadSwap`.

Results:

- 36 tables inspected;
- 35 are admissible under the current strict-increase checks;
- `starb4_cm.csv` is rejected because theta decreases near saturation;
- the first violation occurs at row 446 and the decrease continues through the final h=0 row;
- all 35 admissible tables completed the actual interpolation preprocessing and midpoint characterization;
- total theta overshoots = 0;
- total K overshoots = 0;
- global minimum C = `4.33786093674867725e-12`, positive;
- global minimum dK/dh = `2.27733862942200173e-23`, positive.

For `starb4_cm.csv`, theta changes from `0.41959083171` at h=`-1.0964781961 cm` to `0.41959082646` at h=`-1.0715193052 cm`, and then continues decreasing to `0.41957607059` at saturation. The current reader explicitly requires theta to increase with increasing pressure head, so this table cannot be loaded unchanged.

Thus the interpolator behaves regularly for all 35 tables that satisfy the current input contract, but the public table collection itself is not fully compatible with that contract.

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

The executable current-public production-path probe is now closed. On the same 31-day Hupsel control and the same bounds-checked binary:

- `SWSOPHY=0` completed normally with return code 100;
- changing only the typed input switch to `SWSOPHY=1` produced no runtime log and timed out after 20 s.

This binds the source-audit gap to executable behavior: `SWSOPHY=1` is **not production-executable through the current typed SWAP input path**. The current schema accepts the switch but supplies none of the table state consumed by the solver.

## Source-authority boundary

The executable end-to-end experiments above use the public/transitional SWAP source lineage whose current table engine is byte-identical between the tested pre-strangler and current-public pins. They are not yet an execution of the immutable supplied SWAP 4.3.1 B0 archive.

Canonical SWAP5 authority defines B0 by the supplied `SWAP_4.3.1.zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The canonical repository also records that a byte-identical unpacked B0 source mirror is still pending because the source archive contains non-UTF-8 bytes and the historical baseline must not be silently re-encoded.

Therefore these results establish the behavior of the current/public table implementation and the tested legacy-input lineage. A final claim specifically about the exact supplied 4.3.1 B0 binary/source still requires running the same gates through `tools/vq/b0_source_runner.py` against the canonical raw archive.

## Current disposition

The table option is **not globally "broken"**, but neither is it currently safe to call it a generally working production option.

The bounded conclusion is:

1. the core table interpolation is numerically well behaved for the tested normal range and for all 35 BOFEK2012/Staring tables that satisfy the current ReadSwap input contract;
2. the legacy-input route works very accurately for Hupsel with `SWKIMPL=0`;
3. the existing implementation is slower, not faster, in the repeated Hupsel benchmark;
4. the table route has a reproducible dry-side derivative bounds defect;
5. the `SWKIMPL=1` table route has a reproducible severe convergence/runtime defect associated with the saturated dK/dh sentinel and is not qualified;
6. the current public typed production input path accepts `SWSOPHY=1` but does not provide the required table state; the bounded executable probe stalls and times out.

No production admission or performance claim should be made until points 4-6 are resolved or explicitly excluded from the intended application envelope. In addition, `starb4_cm.csv` must be corrected or deliberately excluded before the 36-file BOFEK2012/Staring set can be treated as a valid table library.
