# F-ROMV2 D13 — FMC groundwater-front adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D13  
**Decision:** **FMC_GW200_RETAINS_GROUNDWATER_BRANCH_RESEARCH_CANDIDACY**

## Question

D13 is the first full SWAP5 hydrological discriminator for the
finite-water-content / Soil Moisture Velocity Equation family selected in D11
and equation-qualified in D12.

The experiment is deliberately narrow.

It exercises only the literature-supported groundwater-front branch:

- capillary groundwater fronts;
- capillary relaxation;
- explicit finite-volume exchange with a fixed water table.

It does **not** exercise:

- surface infiltration fronts;
- falling moisture slugs;
- ET or root-water uptake;
- ponding/runoff;
- arbitrary nonzero SWAP prescribed bottom head.

The comparison is development evidence, not blind application qualification.

## Frozen authority

D12 froze before SWAP trajectory exposure:

- 200 moisture-content bins;
- B01 hydraulic constitutive relations;
- explicit forward-Euler process stepping;
- maximum process substep of 10 s;
- finite-volume water accounting;
- groundwater-front equation from Ogden et al. (2015).

D13 retains those choices unchanged.

The groundwater-front state is

[
H_j
]

for moisture bins (j=101,ldots,199), above a baseline bin
(i=100) corresponding to effective saturation 0.50.

The front law is

[
rac{dH_j}{dt}
=
rac{K(	heta_j)-K(	heta_i)}
     {	heta_j-	heta_i}
left(
rac{|psi(	heta_j)|}{H_j}-1
ight).
]

Hydrostatic equilibrium is therefore (H_j=|psi_j|).

Capillary relaxation rank-orders the front depths without changing the
finite-volume water amount.

## Prospective design amendment

The first draft used the D12 analytical-preflight baseline
(S_e=0.15).

Before any D13 preflight or SWAP trajectory execution, direct constitutive
evaluation showed that several lambda-scaled front depths would exceed the
160-cm research column.

That draft was amended prospectively to exact bin 100/200,
(S_e=0.50).

No SWAP outcome and no D13 preflight result existed when this amendment was
made.

The four frozen initial front families then became:

- G25: (H_j=0.25|psi_j|);
- G50: (H_j=0.50|psi_j|);
- G75: (H_j=0.75|psi_j|);
- G125: (H_j=1.25|psi_j|).

All are physically inside the 160-cm column without clipping.

## Full-algorithm preflight

Preflight workflow run **35451887500** passed before any SWAP trajectory was
generated.

The four cases all satisfy:

- finite and ordered front states;
- movement toward hydrostatic equilibrium;
- exact capillary-relaxation storage preservation;
- exact explicit finite-volume mass closure;
- physically correct groundwater-exchange direction.

G25, G50 and G75 draw water upward from the groundwater boundary.

G125 drains water back toward groundwater.

No lambda, bin count, substep or equation is retuned after this result.

## Immutable comparator execution

Primary workflow run **35452125577**, job **105920995915**, executed head

`9d66a3e8a7fda6d1e456188cfc87cf9f884075a4`.

Artifact:

- ID: **10587057124**
- digest:
  `sha256:03ef5de0264aa60bab1f2aec29a0c6800df8384e000d090729bf23c913316408`
- preflight result SHA-256:
  `ac9be533a406bd91d1941e79bb9c4bde77c3c403a564550ae762369986fb7257`
- hydrological result SHA-256:
  `28d0acdc99b45cf679449985e7d9bb20eb7b2b707f1b5b256d2af1953323b68c`.

R16 O0/O2 output is bitwise identical.

R2 O0/O2 output is bitwise identical.

## Matched initial conditions

The finite-water-content profile is mapped exactly into R16 and R2 as
cell-average water content.

At height (y) above the lower boundary,

[
	heta(y)
=
	heta_i
+
Delta	heta
sum_j I(H_jge y).
]

For each Richards cell, D13 integrates this profile over the cell thickness,
then inverts the B01 retention relation to obtain the initial pressure head.

The initial total storage of FMC, R16 and R2 agrees within the frozen
(10^{-12}) cm requirement.

The subsequent forcing is identical:

- zero prescribed top flux;
- zero pressure head at the bottom;
- no sources or sinks.

Thus the comparison tests relaxation and groundwater exchange, not differing
initial water inventories.

## Integrity

FMC_GW200 completes all four 64-step histories.

There are:

- no nonfinite front states;
- no clipping;
- no hidden mass correction;
- no full-order fallback;
- no training or calibration.

Each 0.001-day observation interval is integrated with nine equal internal
substeps of 9.6 s, satisfying the already frozen 10-s maximum.

Maximum substep mass residual is exactly zero at the reported precision.

Maximum capillary-relaxation storage change is exactly zero.

The candidate therefore passes the non-negotiable integrity layer.

## Development frontier

Pooled discrepancy relative to R16 is:

| metric | FMC_GW200 | R2 |
|---|---:|---:|
| total-storage RMSE | **0.22874 cm** | 0.39853 cm |
| cumulative bottom-exchange RMSE | **0.22874 cm** | 0.39853 cm |
| terminal bottom-flux RMSE | **5.8855 cm d-1** | 10.0978 cm d-1 |
| bottom-flux sign errors | 1/256 | 1/256 |

Relative to R2, FMC reduces the pooled storage/cumulative RMSE by about
**42.6%** and the terminal bottom-flux RMSE by about **41.7%**.

Both preregistered frontier views pass:

- balance view: PASS;
- transient groundwater-flux view: PASS.

This is the first tested non-Richards physical reduction in F-ROMV2 that
crosses the admitted R2 development frontier on both declared views.

## Profile fidelity

FMC is not pointwise identical to R16.

Pooled R16-cell-average water-content RMSE is about

**0.00411 m3 m-3**.

The error is strongly state dependent:

- G25: about 0.00731;
- G50: about 0.00341;
- G75: about 0.00142;
- G125: about 0.00074.

The most under-relaxed capillary fringe is therefore the hardest case.

That gradient is scientifically plausible: the advection-like finite-water
content representation deliberately omits part of the diffusion-like Richards
profile dynamics.

## History-level interpretation

G25 is the most difficult history.

Its final cumulative groundwater-exchange discrepancy is about 0.614 cm and
its bottom-flux RMSE is about 9.75 cm d-1.

G125 is much closer:

- storage RMSE about 0.0421 cm;
- bottom-flux RMSE about 1.18 cm d-1.

The sole pooled sign error occurs in G125.

These values are development observations, not application thresholds.

## What D13 establishes

D13 supports the narrow statement:

> A literature-bound, mass-conservative finite-water-content groundwater-front
> representation can outperform the two-cell Richards comparator for transient
> capillary-fringe relaxation in homogeneous B01 while using no nonlinear
> Richards solve.

That is a meaningful positive result.

It is **not** yet a general unsaturated-zone model result.

## What remains untested

D13 says nothing yet about the process branch that dominates most atmospheric
forcing applications:

- infiltration-front creation and motion;
- rainfall-rate changes;
- falling moisture slugs;
- post-infiltration redistribution;
- ponding/deponding;
- coupling of surface-driven and groundwater-driven fronts.

It also says nothing about:

- ET;
- root-water uptake;
- heterogeneous soils;
- arbitrary SWAP lower-boundary pressure heads;
- seasonal or multi-year balance;
- live MODFLOW coupling;
- same-runtime end-to-end speed.

## Next discriminator

The next bounded workunit should test the **surface infiltration /
redistribution branch** of the same frozen FMC family.

That workunit must, before SWAP comparison:

1. reconcile the published infiltration-front, front-collision and falling-slug
   bookkeeping;
2. reproduce an analytical or literature-supported infiltration control;
3. retain the D12 200-bin discretization and 10-s maximum infiltration step;
4. keep the lower boundary inside direct FMC authority;
5. keep ET/root uptake outside scope.

Only if that branch also remains hydrologically useful is a broader
groundwater-plus-atmosphere FMC model justified.

Formal performance qualification remains premature until at least one broader
combined process envelope survives.

Production ROM remains unauthorized.
