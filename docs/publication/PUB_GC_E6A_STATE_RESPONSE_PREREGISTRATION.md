# PUB-GC E6a preregistration — initial-state response screen

## Status

**FROZEN BEFORE FIRST E6a EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@d443000631f032bc0ba3e4c39f566da3cc05a3c6`

Publication line: PUB-GC / COUPLE.

## Purpose

E3 showed that the original F-GC44 fixture is a weak-feedback control: strong coupling closes the interface rigorously, but the groundwater-head correction remains extremely small. Increasing flux and window length eventually encountered the prescribed-head SWAP response envelope before producing a materially larger feedback.

E6 therefore changes the **accepted hydrological state**, not the coupling tolerances.

E6a screens increasingly wet / shallow initial hydrostatic profiles while preserving:

- the same FMR/Reference-Richards backend;
- the same soil hydraulic parameterization;
- the same fixed top-flux boundary;
- the same groundwater coupling plane and datum;
- the same transaction/retry policy;
- the same predictor/corrector ownership semantics.

No new production process is activated.

## Why drainage and root uptake are not used in E6a

Active drainage was investigated first because F-GC31 already admits its directional response. However, in the current head-driven FMR corrector the drainage response is evaluated from the accepted/base-state groundwater level before the Richards solve. The F-GC31 smooth-freatic projection is explicitly a prescribed-qbot route. Therefore active drainage is lagged within one same-origin prescribed-head corrector and does not provide the desired direct candidate-head dependence.

Root uptake is likewise materialized from committed-state process evaluation and then supplied as a fixed sink to the Richards solve.

Dynamic surface evaporation is hydraulically state-dependent, but the current serialized FMR coupling backend binds the fixed-flux top-boundary provider; adding the dynamic-top provider to this coupling route would be a new capability workstream rather than a clean publication experiment.

E6a therefore isolates the state effect first.

## State parameterization

The existing F-GC44 initial profile is generated from a top-node pressure head `H0_CM` and the fixed vertical node spacing. E6a changes only that profile origin:

```text
H0 = -75, -50, -25, -10, -5 cm
```

More positive values represent progressively wetter / shallower hydraulic states.

The existing `H0=-75 cm` case is the control.

No H0 >= 0 case is included in the first screen to avoid silently crossing into a ponded/surface-saturated initial condition.

## Window matrix

Two already demonstrated low-flux windows are used:

```text
DeltaT = 1e-3 day
DeltaT = 1e-2 day
q_bot,predictor = 1e-6 cm/day
```

Total: 10 baseline states.

These correspond to the robust low-flux E4 B2/B4 regimes at H0=-75 cm.

## Head-response scan

For each baseline:

1. initialize the real SWAP predictor from the configured initial profile;
2. record predictor reference head and supplied response `u_A`;
3. evaluate prescribed-head correctors from the same immutable accepted origin at

```text
H_ref +/- deltaH
```

for:

```text
deltaH =
1e-7, 3e-7, 1e-6, 3e-6, 1e-5, 3e-5, 1e-4 m.
```

Every candidate is discarded after observation.

No head perturbation is made authoritative.

## Measured response

For each symmetric valid pair:

```text
J_R(deltaH)
  = [V_u(H_ref+deltaH)-V_u(H_ref-deltaH)]/(2 deltaH)
```

where:

```text
V_u = q_swap * DeltaT_seconds.
```

The same accepted-sign convention as E4 is used.

The screen records:

- predictor initialization status;
- `H_ref`;
- `u_A`;
- success/failure of every plus/minus trial;
- `J_R(deltaH)`;
- maximum symmetric admissible perturbation;
- local response magnitude;
- trial residual/mass observables already exposed by the F-GC44 qualification bridge where available.

## Derivative plateau

A local `J_R` estimate is considered identifiable if at least three consecutive valid perturbation scales agree to within 1% of their median.

If multiple qualifying triplets exist, use the smallest-perturbation qualifying triplet as the primary local estimate.

No interpolation across failed perturbation scales is allowed.

## Primary selection rule for E6b

A candidate state advances to live-MODFLOW E6b only if:

1. predictor initialization succeeds;
2. a symmetric local `J_R` plateau exists;
3. at least `deltaH=1e-6 m` is admitted on both sides;
4. the local response magnitude or admitted head domain is scientifically more promising than the H0=-75 control.

The primary candidate is chosen by the largest absolute local `J_R` among states satisfying the first three conditions.

If response magnitudes are comparable, prefer the state with the wider symmetric response domain.

## Stop/falsification conditions

E6a is allowed to produce a negative result.

If wetter/shallow profiles:

- do not initialize;
- lose symmetric head-response admissibility;
- or do not materially increase the local response;

then the current simple four-node F-GC44 fixture is not an adequate vehicle for the desired hydrologically material E6 case. The next step must then use a different admitted hydrologic profile/application rather than relaxing numerical tolerances.

## Scope

E6a is a qualification/publication experiment only.

It does not:

- modify production physics;
- change coupling tolerances;
- admit a new groundwater coupling mode;
- claim realism of the synthetic four-node profile;
- establish a regional hydrologic application.
