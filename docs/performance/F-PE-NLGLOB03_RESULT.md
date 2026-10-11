# F-PE-NLGLOB03 result — residual-floor structure attribution

Date: 2026-09-29

Status:

`NLGLOB03_MIXED_BALANCE_FLOOR_STRUCTURE`

Canonical base:

`integration/f-ci-canonical@ad1c4b9193238a46dff95bd30e251adfc0426302`

Qualification authority:

- workflow run: `36538655668`;
- job: `109308627200`;
- conclusion: SUCCESS.

## Coverage

PASS.

- audited failing Newton iterations: 768;
- poor-model near-floor primary iterations: 333;
- adequate-model iterations: 433;
- residual-vector coverage: 100%;
- finite diagnostics: 100%;
- process failures: 0.

## Dominance structure

Within the preregistered poor-model near-floor primary subset:

- total balance dominant: `0.65766`;
- compartment balance dominant: `0.34234`.

Thus both components materially contribute.

## Stable-summation result

Compensated/high-accuracy summation does not explain the total-balance signal.

Observed:

- fraction of total-dominant primary iterations with >=25% change in r_tot: `0.0`;
- fraction crossing from naive r_tot > 1 to compensated r_tot <= 1: `0.0`;
- route-mode families satisfying the preregistered summation direction: `0/6`.

Median primary values:

- r_cp: about `2.059`;
- r_tot_naive: about `2.455`;
- r_tot_fsum: about `2.455`;
- kappa_sum: about `3.165`.

For every route/mode family the median compensated and ordinary total-balance ratios are numerically identical at the reported precision.

Therefore:

`NLGLOB03_TOTAL_BALANCE_SUMMATION_SIGNAL`

is rejected.

## Route/mode structure

Total-dominant primary counts:

- FLUX / KLAG: 46;
- FLUX / TG: 47;
- HEAD / KLAG: 43;
- HEAD / TG: 30;
- RUNOFF / KLAG: 26;
- RUNOFF / TG: 27.

No family shows a compensated-summation crossing signal.

The behavior is therefore shared across routes and both temporal modes.

## Interpretation

NLGLOB03 narrows the NLGLOB02 floor attribution.

The late-iteration near-floor blocker is not caused by the final summation of otherwise well-resolved compartment residuals.

The remaining numerical floor must arise earlier, for example in one or more of:

- storage-increment subtraction;
- flux-difference cancellation;
- constitutive evaluation at nearly identical states;
- representation limits in individual compartment residual terms;
- mixed contribution of local compartment and global balance floors.

This result does not yet choose among those mechanisms.

## Consequence

Do not:

- replace total-balance `sum` with compensated summation as a solver repair;
- relax BALTOL02;
- introduce a floor-aware acceptance rule yet;
- alter mass conservation;
- alter MAXIT, backtracking, dt or K staging.

Open a separate residual-term decomposition workunit before any convergence-contract change.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, route/event or solver-policy change.

`LEGACY_NUMERICS` remains production default.
