# TAB-HYD typed non-equilibrium Reference Richards preregistration

Date: 2026-09-23

Status: **preregistered research gate; no production implementation**

## Objective

Determine whether the raw-head400 typed provider remains hydrologically faithful and materially
faster than the canonical analytical MvG provider once Reference Richards is driven through a
changing, non-equilibrium K0 trajectory rather than repeated equilibrium solves.

## Frozen representation

Do not change:

- 400 physical knots uniformly distributed in log10(-h);
- raw h interpolation coordinate;
- ln(K) ordinate;
- explicit wet theta/C branch;
- explicit Ksat plateau;
- current TSPACK preprocessing/evaluation;
- current provider ABI;
- current canonical Reference-Richards residual and K0 execution policy.

## Materials

Run independently for:

- B4;
- B9;
- B12;
- O13.

## Trajectory protocol

Use the same four-node canonical Reference-Richards test geometry for both providers.

For each material:

1. initialize both routes at uniform h=-75 cm from their own constitutive provider;
2. use the **same absolute top and bottom flux forcing** for analytical and table routes;
3. apply a fixed predeclared 16-step factor sequence relative to the analytical equilibrium
   conductivity at h=-75 cm:

   `[0.80, 0.60, 1.20, 1.40, 0.70, 0.50, 1.10, 1.35, 0.90, 0.65, 1.25, 1.50, 0.75, 0.55, 1.15, 1.30]`;

4. keep bottom flux fixed at the analytical equilibrium gravity flux;
5. set top flux each step to factor times that same gravity-flux magnitude;
6. propagate only each route's own accepted candidate state to its next step;
7. use the same step duration and numerical tolerances for both routes;
8. fail closed on any retry/failure rather than retuning.

## Required outputs

Per material report:

- accepted steps;
- max/RMSE pressure-head difference between provider routes;
- max/RMSE water-content difference;
- max absolute difference in native mass residual;
- max absolute difference in integrated mass residual;
- total nonlinear iterations;
- total Jacobian builds / linear solves;
- repeated trajectory runtime.

## Acceptance interpretation

This research gate is considered hydrologically acceptable only if:

- all 16 steps converge on both routes;
- head max abs <= 0.05 cm and RMSE <= 0.01 cm;
- theta max abs <= 1e-4;
- no material mass-residual degradation beyond 1e-8 cm/day native or 1e-8 cm integrated;
- no systematic extra nonlinear iterations large enough to explain away the provider speed result.

Performance is descriptive, not a pass/fail threshold. Effects below timing noise are parity.

No production admission follows automatically from a green gate.
