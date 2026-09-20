# TAB-HYD envelope preregistration

Date: 2026-09-20

Status: **PREREGISTERED / EVIDENCE-ONLY / NO PRODUCTION ADMISSION**

## Purpose

Test whether the acceleration candidate identified by the functional audit remains numerically faithful and computationally useful outside the original Hupsel hydraulic parameterization.

The candidate is fixed before inspecting this envelope result:

1. 250 rows per soil-physical layer;
2. knots uniform in `x = -ln(1-h)` over the negative-head range plus the saturated endpoint;
3. direct O(1) interval indexing;
4. existing TSPACK interpolation inside the selected interval;
5. zero `dK/dh` on residual branches where K is already held constant;
6. otherwise unchanged analytical/table residual policy.

## Scenario matrix

All scenarios reuse the same Hupsel application and meteorological forcing so that changes can be attributed mainly to hydraulic state and constitutive shape.

| scenario | top/subsoil Staring class | initial state | lower boundary | stress purpose |
| --- | --- | --- | --- | --- |
| coarse_dry_free | B4 / O5 | GWLI -180 cm | free/no-flow legacy Hupsel option | coarse, high-K, dry |
| loam_mid_free | B9 / O9 | GWLI -75 cm | same Hupsel lower boundary | intermediate loam |
| clay_wet_free | B12 / O13 | GWLI -40 cm | same Hupsel lower boundary | heavy clay, wet |
| coarse_dry_pulse | B4 / O5 | GWLI -180 cm | same Hupsel lower boundary | strong infiltration pulse |
| loam_capillary | B9 / O9 | GWLI -120 cm | prescribed groundwater at -120 cm | capillary-support regime |

The selected Staring parameters come from the checked-out `staringreeks1994.csv` authority. The scenarios are hydraulic stress cases, not claims that the unchanged Hupsel heat/vegetation parameterization is a physically complete representation of those soil classes.

## Numerical comparisons

For every scenario:

- analytical vs direct-table with `SWKIMPL=0`;
- derivative-consistent analytical vs derivative-consistent direct-table with `SWKIMPL=1`;
- analytical `SWKIMPL=0` vs analytical `SWKIMPL=1` as a diagnostic, not as a table fidelity gate.

All routes must complete normally and produce the same number of daily result rows.

## Preregistered table-fidelity envelope

For analytical vs direct-table comparisons:

| output | max absolute difference | RMSE |
| --- | ---: | ---: |
| GWL | <= 0.05 cm | <= 0.01 cm |
| DSTOR | <= 0.02 cm | <= 0.005 cm |
| DRAINAGE / DRN | <= 0.02 cm | <= 0.005 cm |
| QBOTTOM | <= 0.02 cm | <= 0.005 cm |
| TACT | <= 0.02 cm | <= 0.005 cm |

A missing metric is not fabricated; it is simply not gated for that case.

These limits are intentionally much wider than the approximately `4.3e-4 cm` Hupsel GWL maximum difference already observed, so the gate tests transfer rather than reproducing the original case.

## Performance measurement

Performance is measured only after the fidelity runs complete.

For each scenario under corrected `SWKIMPL=1`:

- one warm-up analytical run;
- one warm-up direct-table run;
- six order-alternating paired runs;
- report analytical median, table median, median paired runtime ratio, table wins out of six, and pairwise range.

No speedup threshold is imposed post hoc. A broader speedup claim requires a consistent pattern across the scenario set, not one favorable case.

## Interpretation boundary

Passing this gate would support the claim that the direct-index table candidate transfers across a deliberately broader hydraulic envelope. It would not:

- admit tabulated hydraulics into SWAP5 production;
- validate exact B0 SWAP 4.3.1 behavior;
- resolve the dormant/current-public typed-input integration gap;
- establish a general performance claim across every SWAP application.
