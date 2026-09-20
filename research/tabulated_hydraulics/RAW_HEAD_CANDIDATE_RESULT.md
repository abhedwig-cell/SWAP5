# TAB-HYD raw-head candidate result

Date: 2026-09-20

Status: **research candidate; not production-admitted**

> **Supersession note (2026-09-20):** the first raw-head qualification run (`35533250183`) used a research interval-hint condition that relied on Fortran `.and.` evaluation not touching `sptab(...,0)` when `klast=0`. Fortran does not guarantee such short-circuit evaluation. A bounds-checked constitutive run exposed the invalid index. Commit `1b0a24120f910dc0809f550ad41bd200e27ae8ed` replaces the condition by a structurally bounds-safe two-stage test. All raw-head fidelity and performance numbers below are therefore **provisional historical evidence** until reproduced by the bounds-safe rerun.

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
