# TAB-HYD status: current tabulated soil hydraulics

Date: 2026-09-20

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



### 10. Constitutive microbenchmark explains the whole-model parity

The actual public wrapper functions were benchmarked at `-O3` over 256 representative pressure heads. The same source functions were used for analytical MvG, the legacy table lookup and the direct-index TSPACK table route.

Median costs were:

| operation | analytical MvG | legacy table | direct-index table |
| --- | ---: | ---: | ---: |
| `watcon` | 41.05 ns/call | 51.73 ns/call | 38.50 ns/call |
| `moiscap` | 42.92 ns/call | 53.23 ns/call | 41.31 ns/call |
| `hconduc` | 63.45 ns/call | 55.92 ns/call | 41.98 ns/call |
| theta + C + K triplet | 148.66 ns/set | 159.83 ns/set | 122.97 ns/set |

Relative to analytical MvG, the direct-index table route is:

- about 6.2% faster for `watcon`;
- about 3.7% faster for `moiscap`;
- about 33.8% faster for `hconduc`;
- about 17.3% faster for an artificial theta+C+K triplet.

This reconciles the local speedup with the full Hupsel runtime parity. In the `SWKIMPL=0` Richards iteration, `moiscap` is evaluated each nonlinear iteration and `watcon` is evaluated after the head update, whereas conductivity is not recomputed inside the nonlinear iteration in the same way. The two frequently repeated functions therefore gain only a few percent from the direct table representation. The much larger local gain in `hconduc` is not exercised often enough in this execution mode to move total runtime measurably.

The original acceleration hypothesis is therefore only partly supported: the direct-index table representation **is locally cheaper than MvG**, but for the tested `SWKIMPL=0` Hupsel workload that local advantage is too small in the dominant call pattern to yield a whole-model speedup.


### 11. TAB-HYD-003: the analytical default-MvG SWKIMPL=1 control also had a residual/Jacobian mismatch

The large difference previously observed between corrected table `SWKIMPL=1` and analytical `SWKIMPL=1` was traced to a second consistency defect rather than to table interpolation.

The default analytical MvG residual route clamps K to Ksat when `h_enpr > -0.01 cm` and relative saturation exceeds `1-1e-6`. Its `dhconduc` route does not mirror that clamp and continues to return the derivative of the unclamped MvG relation.

A current-public wrapper probe demonstrates the mismatch directly. For the Hupsel topsoil:

- at `h=-0.005 cm`, residual K = `12.52 cm/d`, finite-difference dK/dh of the implemented residual = `0`, but code dK/dh = `23.1396`;
- at `h=-0.001 cm`, residual K = `12.52 cm/d`, finite-difference dK/dh = `0`, but code dK/dh = `68.5089`.

A research-only derivative-consistency candidate, changing only that already-constant Ksat branch to `dK/dh=0`, radically changes the interpretation of the Hupsel `SWKIMPL=1` comparison:

- unmodified analytical K0 versus analytical K1: GWL max abs `1146.52418 cm`, RMSE `1091.56561 cm`;
- analytical K0 versus consistency-corrected analytical K1: GWL max abs `0.62579 cm`, RMSE `0.0434817 cm`;
- corrected analytical K1 versus corrected table K1: GWL max abs `0.00043 cm`, RMSE `1.54e-5 cm`; drainage and TACT match at written precision.

Thus the earlier catastrophic analytical/table `SWKIMPL=1` discrepancy was not evidence that the table representation fails. Both routes contained near-saturation Jacobian-policy issues. Once the residual/Jacobian branch policy is made consistent in both, their implicit trajectories agree closely.

This finding is recorded as `TAB-HYD-003-default-mvg-ksat-jacobian.md`. It is source-bound to the public/transitional lineage until exact B0 execution becomes available.

The current SWAP5 default-MvG provider still contains the residual Ksat clamp, but F-SI09 explicitly does not admit `SWKIMPL=1` and the provider currently reserves `dconductivity_dhead` as zero. This is therefore an admission prerequisite for a future implicit-conductivity route, not a presently admitted SWAP5 production defect.


### 12. Direct-index tables become measurably faster on the corrected SWKIMPL=1 route

After applying both bounded derivative-consistency candidates, the direct-index TSPACK representation was benchmarked against the corrected analytical default-MvG route over the full 2002-2004 Hupsel case.

Hydrological fidelity relative to the corrected analytical `SWKIMPL=1` control remained very high:

| route | GWL max abs (cm) | GWL RMSE (cm) | DSTOR max abs (cm) |
| --- | ---: | ---: | ---: |
| dense legacy TSPACK | 0.00043 | 1.5402e-5 | 1.41e-10 |
| direct TSPACK 150 | 0.00043 | 1.6693e-5 | 1.0e-5 |
| direct TSPACK 250 | 0.00043 | 1.5473e-5 | 1.06e-9 |
| direct TSPACK 400 | 0.00043 | 1.5768e-5 | 3.22e-10 |

Drainage and TACT for the 150-400 direct routes matched the corrected analytical control at written output precision, except for a `1e-5 cm` drainage-scale difference in the 100-row route.

A 12-round order-balanced repeated benchmark gave:

- corrected analytical `SWKIMPL=1`: median `1.61785 s`;
- dense legacy TSPACK: median `1.66786 s`, `+3.09%`;
- direct TSPACK 150: median `1.54259 s`, `-4.65%`;
- direct TSPACK 250: median `1.51763 s`, `-6.19%`.

Using per-round paired comparisons, the 250-row direct route was faster than the analytical control in all 12 rounds. The median paired reduction was `6.19%`, with observed round-wise reductions from about `3.10%` to `9.01%`.

This is the first whole-model evidence in this workstream that a high-fidelity table representation can produce an actual speedup rather than merely remove legacy table overhead. The result is specific to the corrected `SWKIMPL=1` execution regime and the Hupsel workload. It is not yet a general SWAP performance claim.

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
3. **Performance:** the existing dense lookup route is slower. With `SWKIMPL=0`, O(1) direct indexing removes the penalty but only reaches whole-model parity. With the derivative-consistent `SWKIMPL=1` route, direct TSPACK tables at 150-250 rows are both high-fidelity and measurably faster than corrected analytical MvG; the 250-row route was about 6.2% faster in the current repeated Hupsel benchmark.
4. **Jacobian consistency:** the table endpoint derivative implementation contains a real defect, and the legacy/public analytical default-MvG route contains a second Ksat-clamp derivative inconsistency. Bounded zero-derivative candidates over the already-constant residual branches remove the reproduced pathological `SWKIMPL=1` behavior. The independently discovered analytical Ksat-clamp mismatch confirms that the unmodified analytical `SWKIMPL=1` route was not a valid reference for this test.
5. **Exact B0 authority:** not yet executed for this finding.
6. **Current public production route:** `main` accepts the typed switch but does not supply table state; the newer `development` branch explicitly marks `SWSOPHY=1` dormant and fatal-errors. There is therefore no operational current-public table route to admit as-is.
7. **Table library quality:** `starb4_cm.csv` must be corrected or excluded before the complete 36-file public set can be treated as ReadSwap-compatible.
8. **Implicit analytical control:** default MvG contains a near-saturation Ksat-clamp Jacobian mismatch on the tested public lineage. A residual-consistent derivative candidate reduces the Hupsel K0/K1 GWL discrepancy from more than 11 m to 0.626 cm and makes corrected analytical/table K1 trajectories agree within 0.00043 cm maximum GWL difference.

The acceleration hypothesis is now conditionally supported. Direct indexing removes the legacy lookup penalty; under corrected `SWKIMPL=0` this only reaches parity, while under corrected `SWKIMPL=1` a 150-250 row direct TSPACK representation produces a repeatable 5-6% whole-model speedup in Hupsel with near-analytical hydrological output. The next question is whether that gain survives a broader soil/forcing/application-envelope qualification and whether the same representation can be cleanly admitted through the SWAP5 typed constitutive-provider architecture.


### 13. Broad-envelope gate failed and the first direct-TSPACK candidate is superseded for transfer testing

The preregistered five-scenario transfer gate did **not** pass. A repaired non-fail-fast diagnostic subsequently completed 16 of 20 scenario/route combinations and preserved the failure without changing acceptance limits.

The decisive new result is that the first 250-row direct-TSPACK conductivity representation is not shape-safe across the selected Staring envelope.

For the generated B12 table, the actual table engine produced:

- maximum sampled `|dK/dh| = 3.87e4`;
- minimum sampled `dK/dh = -19.85`;
- maximum relative K error of about `0.71` in the direct analytical/table derivative-shape comparison.

For O13, maximum sampled `|dK/dh|` was about `1.86e3` and maximum relative K error about `0.53`.

This is not an arbitrary spline accident. The implemented analytical default-MvG residual itself switches to Ksat at `Se > 1-1e-6`. Across the 30 StaringSeries1994 parameter rows, 21 have a Ksat/K-below jump factor of at least 1.05 and 9 have a factor of at least 1.25. B12 changes from about `5.00` to `15.46 cm/d` at that branch, a factor `3.09`; O13 changes from about `1.536` to `3.32 cm/d`, factor `2.16`.

A single continuous log(K) spline therefore cannot be a faithful representation of the implemented residual across this branch. It bridges a finite jump, which explains the extreme near-saturation table derivative and the large K0 transfer errors observed for loam-mid and clay-wet cases.

The original direct-TSPACK candidate remains valid evidence for the Hupsel parameterization, but it is **superseded as the transfer candidate**. The next research candidate keeps the Ksat plateau as an explicit branch and interpolates only the continuous sub-threshold conductivity relation. This is a new candidate and cannot retroactively change the failed preregistered gate.

See:

- `ENVELOPE_GATE_RESULT.md`;
- `ENVELOPE_DIAGNOSTIC_RESULT.md`;
- `TAB-HYD-004-ksat-clamp-discontinuity.md`.


### 14. 400-row log-head branch-aware candidate closes the K0 transfer gap

The failed 250-row transfer candidate was decomposed further rather than repaired by relaxing the preregistered acceptance limits.

A direct constitutive profile using the actual public hydraulic wrappers and TSPACK evaluator showed that the 250-row log-head branch-aware tables already reproduce the forward hydraulic functions closely over ordinary pressure-head ranges. For B12, maximum relative K error was about `1.46e-4`; the largest C mismatch was concentrated at the extreme wet endpoint. Preserving the analytical linear wet theta/C branch explicitly improved the loam-mid K0 application result from about `0.01858 cm` to `0.00168 cm` maximum GWL difference, but did not remove the B12/O13 clay failure. Thus the wet endpoint policy was a real discrepancy, but not the sole clay mechanism.

A dedicated B12/O13 density sweep then held the branch semantics fixed and varied only the number of log-head knots. The full-period clay-wet K0 result was strongly non-monotone at insufficient resolution because small constitutive differences could cross coupled model thresholds:

| rows | GWL max abs (cm) | GWL RMSE (cm) |
| ---: | ---: | ---: |
| 100 | 0.33073 | 0.0108339 |
| 150 | 32.72104 | 1.90803 |
| 250 | 12.63591 | 1.06518 |
| 400 | 0.00065 | 1.966e-5 |
| 600 | 0.00011 | 3.431e-6 |
| 900 | 0.00003 | 1.130e-6 |

At 400 rows and above, the previous coupled EPOT/EACT/TACT divergence disappeared at written output precision. This demonstrates that the large 150-250 row application errors were not evidence of a fundamental inability of tabulated hydraulics to represent the heavy-clay regime. They were a resolution-sensitive threshold amplification.

The 400-row candidate was then rerun through the same five-scenario transfer envelope without changing the original fidelity limits. All five K0 scenario pairs passed, as did the two bounded coarse-soil K1 controls that are executable within the present envelope harness.

Selected K0 maximum GWL differences were:

- coarse-dry free drainage: `1e-5 cm`;
- loam-mid free drainage: `0.00160 cm`;
- clay-wet free drainage: `0.00065 cm`;
- coarse-dry infiltration pulse: `1e-5 cm`;
- loam capillary rise: `0 cm`.

For the clay-wet case, maximum drainage difference was about `1e-10 cm`, maximum DSTOR difference `1e-5 cm`, and TACT matched at written precision. The transfer gate reported `fidelity_failures=0`.

This establishes the current post-failure representation candidate as:

1. 400 generated rows;
2. knots uniform in `log10(-h)` from the dry bound to the generated K-branch threshold;
3. explicit Ksat plateau rather than a spline across the finite K jump;
4. zero dK/dh on the constant K plateau;
5. explicit preservation of the analytical wet theta/C branch;
6. unchanged TSPACK interpolation within the continuous branches.

The result is a **research transfer qualification**, not a production admission. The stock lookup path remains slower than analytical MvG in these runs, so acceleration still depends on replacing the legacy interval lookup without changing the now-qualified representation.


## 2026-09-23 research closure and production handoff

The tabulated-hydraulics research line has reached its natural state boundary.

Current canonical reconciliation:

- `integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`.

Controlling K0 result:

- bounds-safe generated raw-head400 representation remains within the qualified constitutive/trajectory envelope;
- typed provider evaluation is reproducibly about 19% cheaper than the analytical provider;
- canonical Reference-Richards K0 integration shows about 27-31% lower bounded solve cost;
- serialized Reference K0 runtime shows about 28-31% lower bounded trial cost with equal retries/iterations and mass accounting;
- current-canonical dynamic prescribed-qbot transaction/certificate characterization passed in run `35818703618`;
- deterministic preprocessing break-even is approximately 8,860 30-node constitutive vector evaluations.

K1 remains bounded research only. The expanded loam/clay experiment is blocked by the corrected analytical K1 reference itself exceeding the bounded runtime horizon; no broad K1 production claim is made.

The exact whole-Hupsel final application gate remains externally blocked because the authorized SWAP 4.3.1 distribution archive with SHA-256
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
is not available through an authorized raw-byte materialization path.

The research decision is therefore:

**RESEARCH_CLOSED_READY_FOR_SEPARATE_PRODUCTION_PREREGISTRATION**

Formal handoff:

- `research/tabulated_hydraulics/F-TAB02_GENERATED_K0_PROVIDER_HANDOFF.md`;
- `research/tabulated_hydraulics/F-TAB02_GENERATED_K0_PROVIDER_HANDOFF.json`.

Recommended next branch:

`work/f-tab02-generated-k0-provider`

That work unit must start from the live canonical at creation time. The research branch is evidence authority only and must not be merged wholesale into production.


### 2026-09-23 — generated K0 provider research closeout

Current canonical reconciled at:

`integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`.

The generated raw-head400 typed K0 provider research is now closed for
representation/architecture characterization.

Controlling results:

- generated typed provider: ~19% lower constitutive evaluation cost;
- Reference Richards: material runtime reduction with unchanged solve counts;
- serialized Reference runtime: material reduction with equal retries/iterations
  and preserved mass accounting;
- FMR44R current-canonical dynamic prescribed-qbot transaction/certificate:
  PASS, run `35818703618`;
- generic timestep-context capability CTX01:
  PASS, run `35819421154`;
- qualified contract recommendation:
  fail-closed `context_compatible(step_duration)` capability, with hot
  `evaluate(...)` ABI unchanged;
- preprocessing break-even:
  approximately 8,860 30-node vector evaluations.

K1 remains separate and reference-runtime blocked outside the bounded coarse
cases; it is not table-falsified and is not current production scope.

Final exact whole-Hupsel generated-provider qualification is externally blocked
because the authorized SWAP 4.3.1 distribution bytes with SHA-256
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
remain unavailable through a materializable raw-byte path.

See:

- `TYPED_PROVIDER_RESEARCH_RESULT.md`;
- `TIMESTEP_CONTEXT_CAPABILITY_RESULT.md`;
- `GENERATED_K0_PROVIDER_PRODUCTION_HANDOFF.md`;
- `RESEARCH_CLOSEOUT_20260923.md`.

Disposition:

**K0_RESEARCH_CLOSED / PRODUCTION_HANDOFF_READY / FINAL_WHOLE_HUPSEL_ADMISSION_GATE_EXTERNAL_ASSET_BLOCKED**.


### 2026-09-23 — F-SI39/KSATEXM bounded closeout

The final exact Hupsel gate requires the admitted F-SI39 KSATEXM extension.
That subproblem is now closed in research for the exact Hupsel material envelope.

- KX05 constitutive PASS: run `35863485123`;
- zero strict branch-classification mismatches;
- KX06 typed Reference-Richards PASS: runs `35863794528` and
  `35863919254`;
- KX05 preserves KX03 fidelity and solver effort;
- KX05 removes roughly 20-24% of KX03 runtime in the compact fixture;
- active KSATEXM regime returns to slight acceleration versus analytical
  (about 3% in both independent KX06 runs).

Preferred bounded extension handoff: precompute the first floating-active
F-SI39 pressure head from canonical authority at immutable provider
initialization; use generated theta only for the active interpolation fraction.

Generic KSATEXM remains out of scope.

Current canonical at latest reconciliation:
`a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.
