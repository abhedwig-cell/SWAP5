# TAB-HYD raw-head candidate result

Date: 2026-09-20

Status: **research candidate; not production-admitted**

> **Supersession/requalification note (2026-09-20):** the first raw-head qualification run (`35533250183`) used a research interval-hint condition that relied on Fortran `.and.` evaluation not touching `sptab(...,0)` when `klast=0`. Fortran does not guarantee such short-circuit evaluation. A bounds-checked constitutive run exposed the invalid index. Commit `1b0a24120f910dc0809f550ad41bd200e27ae8ed` replaced the condition by a structurally bounds-safe two-stage test. The bounds-safe reruns then reproduced the hydrological result and performance result: all transfer gates passed in run `35534127462`, the all-Staring bounds-checked constitutive scan passed in run `35534127461`, and the envelope timing run `35534127466` completed successfully. The pre-fix run remains historical only; the bounds-safe reruns are the controlling raw-head evidence.

Scope: isolate whether the transformed pressure-head coordinate and associated interval-location work are the dominant residual cost of a high-fidelity tabulated hydraulic route.

## Bound authorities

- Executable legacy-input source: `SWAP-model/SWAP@2a5ace1c06be7a257b64e9ac1896b489533f16e9`.
- Hupsel case: `SWAP-model/swap-testcases@a839e2e905f34dd264ad0c739f638454b3023def`.
- Staring parameters: `Murilodsv/SWAP-SAMUCA/main`.
- Research branch: `research/tabulated-hydraulics-characterization`.
- Canonical SWAP5 remains separate. No production admission is implied.

## Diagnostic basis

The exact-head/call-flow diagnostic on the direct transformed-x candidate showed:

| route | theta eval | K eval | C eval | dK/dh eval | transformed-x hit rate | theta interval hit rate | K interval hit rate | C reuse hit rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| K0 | 1,464,944 | 1,450,776 | 59,272 | 0 | 47.80% | 1.96% | 51.04% | 97.06% |
| K1 | 1,486,769 | 2,847,463 | 60,149 | 1,396,820 | 72.79% | 1.94% | 62.89% | 97.06% |

Evidence run: `35532952556`.

This falsified two candidate explanations for the remaining K0 overhead:

1. C evaluation is not the dominant cost: exact theta/C reuse already hits about 97% of moiscap calls but does not materially improve K0 wall time.
2. TSPACK tension evaluation is not the dominant cost: replacing runtime tension evaluation by ordinary Hermite evaluation with the already-preprocessed TSPACK knot slopes preserved the transfer gate but produced essentially no whole-model speedup.

The remaining high-frequency cost is associated with pressure-head coordinate handling and interval location, especially for theta where exact interval reuse is only about 2%.

## Raw-head formulation

The raw-head candidate keeps the already-proven 400-row physical pressure-head knots and branch policies, but changes the interpolation coordinate:

- spline coordinate: raw pressure head `h`, rather than `x=-ln(1-h)`;
- conductivity ordinate remains `ln(K)`;
- final Ksat plateau remains explicit;
- the wet theta/C branch remains explicit;
- interval location uses a per-node/per-family last-interval hint with bounded binary-search fallback;
- no tolerance-based state reuse is introduced.

Research implementation:

- `research/tabulated_hydraulics/patch_raw_head_logk_lookup.py`
- qualification workflow: `.github/workflows/tabulated-hydraulics-raw-head-logk.yml`

## Hydrological transfer result

Workflow run `35533250183` completed successfully.

All preregistered transfer metrics passed in all tested K0 and bounded K1 scenarios.

Selected GWL errors against derivative-consistent analytical MvG:

| scenario | SWKIMPL | max abs GWL (cm) | RMSE GWL (cm) |
| --- | ---: | ---: | ---: |
| coarse_dry_free | 0 | 0.00001 | 2.93e-6 |
| loam_mid_free | 0 | 0.00163 | 5.29e-5 |
| clay_wet_free | 0 | 0.00821 | 2.48e-4 |
| coarse_dry_pulse | 0 | 0.00001 | 3.01e-6 |
| loam_capillary | 0 | 0 | 0 |
| coarse_dry_free | 1 | 0.00001 | 2.70e-6 |
| coarse_dry_pulse | 1 | 0.00001 | 3.25e-6 |

The wet-clay GWL error is larger than for the transformed log-head400 representation (previously about 0.00065 cm), but remains well inside the prospectively defined GWL gate (max abs 0.05 cm, RMSE 0.01 cm). Flux and storage metrics also pass.

Against the transformed cached table candidate on the standard Hupsel output:

- K0 GWL max difference: `1e-5 cm`;
- K1 GWL max difference: `1e-5 cm`;
- reported drainage, QBOTTOM, TACT and DSTOR differences were zero at written precision.

## Hupsel performance result

The same order-balanced 16-round workflow gave:

| route | median K0 (s) | delta vs analytic K0 | median K1 (s) | delta vs analytic K1 |
| --- | ---: | ---: | ---: | ---: |
| analytical MvG | 1.16704481 | reference | 1.51788778 | reference |
| transformed cached table | 1.21729892 | +4.31% | 1.41779788 | -6.59% |
| raw-head table | 1.16736042 | **+0.027%** | 1.36768404 | **-9.90%** |

Raw-head versus transformed cached table:

- K0: `-4.10%`;
- K1: `-3.53%`.

Interpretation:

- for the tested Hupsel K0 workload, the table route has now reached practical whole-model parity with analytical MvG while retaining the transfer gate;
- for corrected K1, raw-head is materially faster than analytical MvG in this run;
- the gain is consistent with the call-flow evidence that transformed-coordinate work is much more frequently avoided in K1 and was the principal remaining table overhead in K0.

## Claims that are not yet admitted

Do **not** generalize the Hupsel timing to a production-wide speedup yet.

Still required before any performance admission:

1. repeated timing across the preregistered transfer-envelope scenarios;
2. constitutive profiling of raw-head400 over the broader Staring parameter set;
3. resolution/representation confirmation if broad constitutive profiling exposes a raw-head-specific weak regime;
4. typed SWAP5 provider/input design and independent production qualification;
5. exact historical B0 qualification if the claim is stated specifically for supplied SWAP 4.3.1.

## Follow-up work in flight

At the time of this record:

- raw-head + exact theta/C reuse workflow has been queued;
- repeated transfer-envelope performance workflow has been queued;
- all-Staring raw-head constitutive profile workflow has been queued.

These are research gates, not production admission steps.


## Bounds-safe requalification

The repaired raw-head candidate was rerun after the interval-hint bounds fix.

### Transfer fidelity

Run `35534127462`:

- `fidelity_failures=0`;
- wet-clay K0 GWL max abs = `0.00821 cm`, RMSE = `2.48086e-4 cm`;
- loam K0 GWL max abs = `0.00163 cm`, RMSE = `5.2895e-5 cm`;
- coarse K0/K1 GWL max abs = `1e-5 cm`;
- capillary loam K0 GWL difference = `0`.

The bounds-safe rerun therefore reproduces the earlier hydrological result.

### Hupsel repeated performance

Run `35534127462`:

- analytical K0 median = `1.21771565 s`;
- raw-head K0 median = `1.21748346 s`, delta = `-0.0191%`;
- analytical K1 median = `1.56817319 s`;
- raw-head K1 median = `1.41794832 s`, delta = `-9.5796%`.

A second bounds-safe workflow that also measured the full transfer envelope, run `35534127466`, independently gave:

- Hupsel K0 delta = `+0.0090%`;
- Hupsel K1 delta = `-9.5882%`.

Thus the defensible current interpretation is:

- K0: practical runtime parity, not an admitted speedup;
- corrected K1: approximately 9.6% Hupsel speedup in the bounds-safe candidate.

### Transfer-envelope performance

Run `35534127466`, repeated scenario medians:

| scenario | SWKIMPL | raw-head delta vs analytical |
| --- | ---: | ---: |
| coarse_dry_free | 0 | -0.012% |
| loam_mid_free | 0 | -1.687% |
| clay_wet_free | 0 | +3.144% |
| coarse_dry_pulse | 0 | +0.002% |
| loam_capillary | 0 | -1.701% |
| coarse_dry_free | 1 | -10.722% |
| coarse_dry_pulse | 1 | -11.024% |

The K0 timings are small and noisy enough that they support parity rather than a broad speedup claim. The two preregistered K1 cases show a large, consistent speed reduction.

### Raw-head interval-hint behavior

Run `35534160351`:

- K0 theta interval-hint hit rate = `93.88%`;
- K0 K interval-hint hit rate = `92.47%`;
- K1 theta interval-hint hit rate = `93.92%`;
- K1 K interval-hint hit rate = `94.48%`.

Binary-search fallback is therefore only about 5-8% of forward evaluations. Further interval-locator engineering is no longer the primary K0 target.

### All-Staring constitutive scan

Bounds-checked run `35534127461` completed for all 30 Staring parameter rows represented by the source parameter CSV.

Global maximum sampled errors were:

- theta abs = `5.321e-5`;
- C abs = `4.297e-5`;
- log10(K) abs = `3.038e-4`;
- K relative = `3.090e-4`.

The largest sampled `dK/dh` absolute difference was `14.4103` for B12 at `h=-4.6416e-4 cm`, very close to the analytical Ksat-clamp transition. Several other derivative maxima occur exactly at the wet theta branch boundary `h=-0.01 cm`.

This derivative result is a numerical-Jacobian fidelity warning, not a residual K failure: the raw-head route differentiates its own interpolated K relation consistently. Expanded K1 trajectory qualification is therefore required before broadening the K1 claim beyond the preregistered coarse cases.

### Exact theta/C reuse on top of raw-head

Bounds-safe run `35534127458` preserved Hupsel written output exactly between raw-head and raw-head+capacity-reuse for both K0 and K1.

Repeated Hupsel medians:

- raw-head+capacity K0 vs analytical: `-0.006%` (parity);
- raw-head+capacity K1 vs analytical: `-12.770%`;
- raw-head+capacity K1 vs raw-head: `-3.503%`.

The K1 improvement is promising, but it is not promoted beyond research until the expanded K1 envelope closes.


## Typed-provider and Reference-Richards integration result

The legacy-input whole-Hupsel K0 result is **not** the final performance answer for SWAP5, because the current SWAP5 constitutive ABI evaluates water content, capacity and conductivity as one vector provider call.

### Provider-only benchmark

Preregistered workflow run `35535155474` used the existing canonical
`constitutive_hydraulics_provider_t` ABI and compared the current analytical default-MvG provider with the research raw-head provider over all 30 available Staring parameter rows.

Results:

- maximum theta error: `5.321e-5`;
- maximum capacity error: `5.172e-5`;
- maximum log10(K) error: `3.038e-4`;
- analytical provider median: `0.259178 s`;
- raw-head table provider median: `0.2090535 s`;
- table delta: **`-19.34%`**.

This is provider-only evidence, not a whole-solver claim.

### Canonical Reference-Richards provider-seam benchmark

A research integration harness was then built against
`integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.

The harness does not change the production adapter or provider-selection policy. It binds either:

- the admitted analytical `b110_default_mvg_provider_t`; or
- the research `tabhyd_raw_provider_t`

to the **same** request-level `request%evaluation%constitutive` seam of the canonical Reference-Richards solver.

The benchmark uses 32 nodes, the five preregistered transfer-envelope soil pairings, identical boundary/numerical settings, and K0 (`conductivity_implicit_mode=0`). Each timing block executes 4000 full Reference-Richards solves; eight order-balanced blocks are used per scenario.

Workflow run `35535959193` completed successfully.

| scenario | head max diff (cm) | theta max diff | flux max diff | nonlinear iters analytical/table | analytical median (s) | table median (s) | table delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| coarse_dry_free | 2.6703e-5 | 9.63e-9 | 8.53e-12 | 3 / 3 | 0.1215575 | 0.0917380 | **-24.53%** |
| loam_mid_free | 4.1475e-7 | 1.30e-9 | 2.95e-8 | 3 / 3 | 0.1240330 | 0.0905985 | **-26.96%** |
| clay_wet_free | 9.8457e-8 | 1.70e-9 | 6.92e-10 | 3 / 3 | 0.1458675 | 0.1044855 | **-28.37%** |
| coarse_dry_pulse | 2.6703e-5 | 9.63e-9 | 8.53e-12 | 3 / 3 | 0.1210130 | 0.0903600 | **-25.33%** |
| loam_capillary | 1.3989e-7 | 1.12e-9 | 3.05e-9 | 3 / 3 | 0.1315885 | 0.0915680 | **-30.41%** |

The equal nonlinear-iteration counts are important: the timing difference is not caused by a different stopping trajectory in this benchmark.

### Current interpretation

The acceleration hypothesis is now supported at three increasingly integrated levels:

1. provider-only: about 19% faster;
2. canonical Reference-Richards solve through the typed constitutive seam: about 25-30% faster in this bounded 32-node integration benchmark;
3. legacy-input full Hupsel K0: only parity, because that legacy execution path does not exploit the same fused typed-provider structure.

The Reference-Richards benchmark is still a **solver-integration microbenchmark**, not a full production-application timing. It uses research-generated equivalent tables and a synthetic one-step forcing/state setup. It therefore justifies continuing to the serialized Reference/FMR and realistic application timing stages, but it does not justify a portable 25-30% SWAP speedup claim.

No production code was changed or admitted by this benchmark.
