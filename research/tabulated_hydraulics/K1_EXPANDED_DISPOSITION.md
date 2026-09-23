# TAB-HYD expanded K1 disposition

Date: 2026-09-23

Status: **research K1 performance claim remains bounded to coarse cases**

## Existing positive evidence

Bounds-safe raw-head qualification showed approximately 9.6-11% whole-model runtime reduction
for the two preregistered coarse-soil SWKIMPL=1 cases, with the existing transfer metrics green.
Exact theta/C reuse further improved the Hupsel K1 benchmark.

## Expanded-envelope attempt

Workflow `35535291129` attempted the same corrected analytical/raw-head/raw-head-capacity K1
comparison for:

- coarse_dry_free;
- loam_mid_free;
- clay_wet_free;
- coarse_dry_pulse;
- loam_capillary.

The first coarse case completed and remained high-fidelity:

- GWL max abs: `1e-5 cm`;
- GWL RMSE: `2.70e-6 cm`;
- drainage, QBOTTOM and TACT identical at written precision.

The workflow then exhausted the 45 s per-case execution allowance before the next scenario completed.
The failure is therefore **not a demonstrated hydrological-fidelity failure**. It is an
execution/runtime blocker in the expanded K1 numerical regime.

## Scientific consequence

Do not generalize the coarse-soil K1 speedup.

The expanded run shows that SWKIMPL=1 numerical difficulty is strongly regime-dependent.
This is consistent with the independent constitutive scan, which found the largest raw-head
dK/dh difference for B12 close to the Ksat branch transition.

The current admissible statement is:

- coarse K1: promising and fast in the tested bounded cases;
- loam/clay K1: not yet qualified; execution difficulty itself is an open numerical issue;
- production K1: not admitted in current canonical and outside the current production denominator.

No tolerance increase, iteration-ceiling change or solver-policy relaxation is authorized by this work unit.
