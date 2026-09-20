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

For this smooth constitutive curve, very dense tables are therefore not required for interpolation fidelity. Around 100 input points, the conductivity error is already close to the residual error floor of the current interpolation/transformation policy.

### 2. The complete 36-file BOFEK2012/Staring set exposes one source-table incompatibility

The complete public BOFEK2012/Staring table set in `Murilodsv/SWAP-SAMUCA` was checked against the actual strict-increase rules implemented by current `ReadSwap`.

Results:

- 36 tables inspected;
- 35 are admissible;
- `starb4_cm.csv` is rejected because theta decreases near saturation;
- all 35 admissible tables completed the actual preprocessing;
- each interval was sampled at nine interior locations, not only at its midpoint;
- total theta overshoots = 0;
- total K overshoots = 0;
- global minimum C = `3.95537127817299401e-12`, positive;
- global minimum dK/dh = `1.77925057428754186e-23`, positive.

For `starb4_cm.csv`, the first detected decrease is from theta `0.41959083171` at h=`-1.0964781961 cm` to `0.41959082646` at h=`-1.0715193052 cm`; the decrease continues towards the final saturated value `0.41957607059`.

Thus the current interpolator behaves regularly for every table in this set that actually satisfies the current input contract. The table collection itself is not fully compatible with that contract.

### 3. The legacy-input table route is hydrologically faithful for Hupsel with SWKIMPL=0

A full 2002-2004 Hupsel run was executed with daily output for:

- analytical Mualem-van Genuchten hydraulics, `SWSOPHY=0, SWKIMPL=0`;
- generated equivalent tables, `SWSOPHY=1, SWKIMPL=0`.

Both completed normally with 1096 daily result rows. Differences were very small:

- GWL maximum absolute difference: `1.8e-4 cm`;
- GWL RMSE: `6.80e-6 cm`;
- DSTOR maximum absolute difference: `1e-5 cm`;
- rainfall, irrigation, runoff, drainage, QBOTTOM, EPOT, EACT, TPOT and TACT matched at written output precision.

This is strong bounded evidence that the existing table route can reproduce the analytical Hupsel response when the table is generated from the same constitutive functions and `SWKIMPL=0` is used.

### 4. Table density strongly affects fidelity, but hardly affects runtime in the current implementation

A full-period Hupsel sweep varied the table generator from 30 to 900 candidate pressure-head points. After removal of the repeated near-saturated Ksat values, this produced from 22/20 to 638/572 actual rows for the top/subsoil.

Selected results against the analytical `SWKIMPL=0` control:

| candidate points | actual rows top/sub | GWL max abs (cm) | GWL RMSE (cm) | runtime (s, single run) |
| ---: | ---: | ---: | ---: | ---: |
| 30 | 22 / 20 | 0.53839 | 0.11585 | 1.52 |
| 40 | 29 / 26 | 0.14469 | 0.03147 | 1.53 |
| 50 | 36 / 33 | 0.06199 | 0.00967 | 1.53 |
| 75 | 54 / 48 | 0.00751 | 0.000984 | 1.52 |
| 100 | 72 / 64 | 0.00207 | 0.000340 | 1.54 |
| 150 | 107 / 96 | 0.00046 | 0.000120 | 1.53 |
| 250 | 178 / 159 | 0.00018 | 0.0000109 | 1.54 |
| 900 | 638 / 572 | 0.00018 | 0.00000680 | 1.59 |

The analytical control took `1.44 s` in the same sweep. This is exploratory timing because each density was run only once, but the pattern is clear enough to reject one simple hypothesis: reducing the number of rows by an order of magnitude does not make the existing table engine faster than the analytical route.

A separate ten-pair alternating benchmark of the dense table route gave:

- analytical median: `1.41755 s`;
- table median: `1.56812 s`;
- median table/analytical runtime ratio: `1.10597`;
- median table runtime delta: `+10.60%`.

The present table implementation is therefore not an acceleration. If a fast table route exists, the likely target is the per-evaluation interpolation/lookup method rather than merely reducing table length.

### 5. TAB-HYD-001: the table dK/dh endpoint policy is inconsistent with the residual K policy

The existing table `hconduc` route extends K as a constant outside the tabulated theta range:

- wet side: use the last tabulated K;
- dry side: use the first tabulated K.

The corresponding `dhconduc` route does something else:

- wet side: return `1e8`;
- dry side: continue into the table derivative evaluator, which can address table index 0.

This violates the Jacobian-consistency rule already established by SWAP-011: the derivative used by implicit Richards must be the derivative of the actual K relation used in the residual. The derivative of the existing constant endpoint extension is zero.

The finding is recorded separately in `TAB-HYD-001-endpoint-derivative-finding.md`.

### 6. A bounded zero-endpoint dK/dh candidate removes both reproduced endpoint failures

A research-only candidate was tested in which `dhconduc=0` when theta is at or beyond either tabulated endpoint, while the interior interpolation remains unchanged.

Bounds-checked/current-wrapper probes then gave:

- near-saturated dK/dh = `0`;
- dry probe at h=`-1e8 cm`: finite theta, C and K, and dK/dh = `0`;
- the previous dry-side `sptab(...,0)` bounds failure was no longer reached.

The candidate also completed full 2002-2004 Hupsel runs for both table `SWKIMPL=0` and table `SWKIMPL=1`. Comparing those two numerical routes over 1096 daily outputs gave:

- GWL max absolute difference: `0.62579 cm`;
- GWL RMSE: `0.04348 cm`;
- DRAINAGE max absolute difference: `0.00732 cm`;
- DSTOR max absolute difference: `0.00733 cm`;
- TACT max absolute difference: `0.00266 cm`;
- RAIN, IRRIG, RUNOFF, QBOTTOM, EPOT, EACT and TPOT matched at written precision.

This closes the two reproduced endpoint failure mechanisms for the tested current/public lineage and shows that the corrected table `SWKIMPL=1` route can complete a three-year realistic case.

It does **not** yet justify a production/B1 fix claim. Exact SWAP 4.3.1 B0 execution remains unavailable in this workstream because the canonical raw archive cannot currently be materialized through the available file path. Also, `SWKIMPL=0` and `SWKIMPL=1` are distinct numerical linearizations, so their non-zero long-run difference requires an acceptance rule rather than an expectation of bit identity.

### 7. Current public typed production reachability remains a separate blocker

Source audit of `c22bd832...` shows:

- `soil.swsophy` accepts value 1;
- the typed soil schema has no table-file/table-data field corresponding to legacy `FILENAMESOPHY`;
- `config_to_variables` does not populate `numtablay`, `sptablay` or `ientrytablay`;
- `Initialize` explicitly zeros `numtablay` and `sptablay`;
- the `swsophy=1` branch immediately consumes those arrays.

On the same 31-day Hupsel control and bounds-checked current-public binary:

- `SWSOPHY=0` completed normally with return code 100;
- changing only the typed switch to `SWSOPHY=1` timed out after 20 s.

Thus `SWSOPHY=1` is **not production-executable through the current typed SWAP input path**. This capability gap is independent of TAB-HYD-001.


### 8. Direct interval indexing removes the table-runtime penalty

The existing table route spends appreciable time locating an interval through the logarithmic lookup-bin machinery. Two bounded experiments separated interval location from interpolation.

A research-only table representation was generated with negative pressure-head knots uniform in the already-used transformed coordinate

`x = -ln(1-h)`

plus the saturated `h=0` endpoint. This permits O(1) interval selection by arithmetic rather than the existing `log10(-h)` bin lookup.

#### Direct index plus linear interpolation

Replacing both lookup and interpolation by direct-index linear interpolation removed essentially all table overhead, but lost too much trajectory fidelity. In a repeated full-period benchmark:

- analytical median = `1.46789 s`;
- dense legacy TSPACK = `1.61830 s`, ratio `1.10247`;
- direct-linear variants = approximately `1.46795 s`, ratio approximately `1.0000`.

Hydrological error remained material. For example, the 100-row direct-linear route gave GWL maximum absolute difference `0.14452 cm` and RMSE `0.01475 cm` relative to the analytical control.

This shows that the existing runtime penalty is not primarily the arithmetic cost of TSPACK itself.

#### Direct index plus cubic Hermite interpolation

Using the same direct interval index but retaining cubic interpolation with the already-preprocessed endpoint slopes restored high fidelity:

- 150 rows: GWL max abs `0.00018 cm`, RMSE `9.50e-6 cm`;
- 250 rows: GWL max abs `0.00017 cm`, RMSE `6.69e-6 cm`.

The dense legacy TSPACK control had GWL max abs `0.00018 cm` and RMSE `6.80e-6 cm`.

Repeated runtime medians were:

- analytical = `1.41719 s`;
- dense legacy TSPACK = `1.56774 s`, ratio `1.10624`;
- direct cubic 150 = `1.46742 s`, ratio `1.03545`;
- direct cubic 250 = `1.46733 s`, ratio `1.03539`.

Thus direct lookup recovers most, but not all, of the existing table penalty when cubic interpolation is implemented locally.

#### Direct index plus unchanged TSPACK interpolation

The strongest separation experiment changed only interval selection. After the O(1) direct index selected the two knots, the existing TSPACK `my_HVAL/my_HPVAL` evaluation was left unchanged.

At 150-250 rows the hydrological trajectory was effectively indistinguishable from the dense legacy table route at the written-output scale:

- 150 rows: GWL max abs `0.00018 cm`, RMSE `9.25e-6 cm`;
- 250 rows: GWL max abs `0.00017 cm`, RMSE `6.69e-6 cm`;
- dense legacy TSPACK: GWL max abs `0.00018 cm`, RMSE `6.80e-6 cm`.

Repeated benchmark medians were:

- analytical = `1.31706 s`;
- dense legacy TSPACK = `1.41739 s`, ratio `1.07618`;
- direct TSPACK 100 = `1.31713 s`, ratio `1.00006`;
- direct TSPACK 150 = `1.31714 s`, ratio `1.00006`;
- direct TSPACK 250 = `1.31706 s`, ratio `0.999999`;
- direct TSPACK 400 = `1.31716 s`, ratio `1.00007`.

This is strong evidence that the approximately 8-11% whole-model penalty of the existing table route in this Hupsel workload comes predominantly from the legacy interval-lookup/data-access path, not from TSPACK interpolation arithmetic. Once that lookup is replaced by direct arithmetic indexing, a high-fidelity table route reaches whole-model runtime parity with direct analytical MvG.

It is **not yet a speedup**. Within measurement resolution, the best direct-index table route is equal to the analytical route rather than faster.



### 9. "Current software" requires a branch distinction

A live reconciliation against the public `SWAP-model/SWAP` repository changes the operational interpretation of the earlier typed-path result.

The public `main` branch at `c22bd832ddf3e53e330a552f5e31e74f183362d1` still contains the table implementation in the active source tree. Its typed schema accepts `swsophy=1`, but does not populate the table state, and the bounded executable probe stalls.

The newer public `development` branch at `b39d4d53028a2ffc1da562200db7b9fc63e7a709` has gone further. Since commit `26fa1c0439b099678ef90fd0274e27da013b7792` (2026-05-24), `sptabulated.f90` is under `src/soilwater/dormant/`. The active hydraulic wrappers explicitly classify `swsophy=1` as dormant and call `fatalerr_collected` rather than attempting table evaluation.

Therefore:

- current public **development**: tabulated hydraulics is deliberately non-operational;
- current public **main**: the switch is still syntactically reachable but table state is not supplied by the typed input route;
- pre-strangler/legacy-input lineage: the table route is executable and can be characterized, which is where the numerical and performance experiments in this workstream are performed;
- exact SWAP 4.3.1 B0: remains the controlling historical source authority, but its raw archive cannot currently be materialized through the available Project-file path, so no byte-exact B0 table claim is made here.

This branch distinction supersedes any unqualified wording that calls the table option simply "working in current SWAP".


## Source-authority boundary

The executable end-to-end experiments use the public/transitional SWAP source lineage. They are not yet executions of the immutable supplied SWAP 4.3.1 B0 archive.

Canonical SWAP5 authority defines B0 by:

- supplied `SWAP_4.3.1.zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The canonical repository records that a byte-identical unpacked B0 source mirror is still pending because the source contains non-UTF-8 bytes and the historical baseline must not be silently re-encoded.

The intended derivative rule itself has stronger repository authority: admitted finding SWAP-011 states that the implicit Richards Jacobian must differentiate the actual conductivity function used in the residual. TAB-HYD-001 applies that same consistency rule to the table endpoint extension.

A final claim specifically about exact supplied 4.3.1 B0 still requires running the table gates through the exact archive authority.

## Current disposition

The functional question can now be split cleanly:

1. **Interior table interpolation:** works well for the tested smooth constitutive curve and for all 35 admissible tables in the tested BOFEK2012/Staring set.
2. **Legacy-input, SWKIMPL=0:** works and reproduces the analytical Hupsel control very closely.
3. **Existing performance:** not faster. Dense tables are about 11% slower in the repeated Hupsel benchmark, and sparse tables do not remove that disadvantage.
4. **Endpoint derivative implementation:** contains a real Jacobian-consistency defect. A zero-endpoint derivative candidate removes both the dry bounds failure and the wet-side `SWKIMPL=1` stall in the tested lineage.
5. **Exact B0 authority:** not yet executed for this finding.
6. **Current typed production route:** cannot currently supply table state and therefore cannot use `SWSOPHY=1` operationally.
7. **Table library quality:** `starb4_cm.csv` must be corrected or excluded before the complete 36-file public set can be treated as ReadSwap-compatible.

The next acceleration question should therefore not be “how many table rows should we use?” The evidence points instead to: **can a much cheaper lookup/interpolation representation preserve the hydrologically required fidelity while outperforming direct analytical constitutive evaluation?**
