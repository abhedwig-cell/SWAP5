# Evapotranspiration demand and root-water uptake

This page documents the bounded reference ET and root-water-uptake formulation represented by the frozen SWAP5 Status-A review baseline. The scope is intentionally narrower than the full historical SWAP evapotranspiration chapter.

## Scope

The documented chain is:

```text
reference ET forcing
        |
        v
restricted ET-demand partition
        |
        +--> potential soil evaporation
        +--> potential pond evaporation
        |
        v
potential transpiration
        |
        v
root-distribution partition
        |
        v
pressure-head drought reduction
        |
        v
actual root-extraction sink
```

The admitted historical formulation behind this page is the restricted reference profile identified by F-DOC18 as `RB1-ET-ROOT-SERIAL`. Current implementation claims are checked against the frozen scientific production baseline rather than inferred from the historical authority alone.

## Restricted reference ET demand

The frozen reference process consumes:

- reference evapotranspiration `ET_ref` in `mm/day`;
- vegetation cover fraction `c`, bounded to `[0,1]`;
- whether the crop has emerged;
- crop factor `k_c` for an emerged crop;
- CO2 transpiration factor `f_CO2` for an emerged crop;
- pond evaporation factor `f_pond`.

Its public potential-demand outputs are in `cm/day`.

For the restricted route, uncovered reference demand is

```text
ET_uncovered = ET_ref (1 - c)
```

and potential soil evaporation is

```text
E_soil,pot = max(0, 0.1 ET_uncovered)
```

while potential pond evaporation is

```text
E_pond,pot = max(0, 0.1 ET_uncovered f_pond)
```

where factor `0.1` converts `mm/day` to `cm/day`.

For an emerged crop, potential transpiration is

```text
T_p = max(0, 0.1 ET_ref c k_c) f_CO2
```

For a non-emerged crop the restricted evaluator does not consume the crop-specific factors and returns zero potential transpiration, while surface demand still uses the current vegetation-cover view.

This is the frozen `SWETR=1`, `SWMETDETAIL=0`, `SWCFBS=0`, `SWINTER=0` reference route. It is not a generic description of all ET methods historically available in SWAP.

## From potential transpiration to potential root extraction

Let `f_i` denote cumulative root fraction at compartment boundary `i`. The frozen root process requires the cumulative fractions over rooted compartments to be monotone, to start at zero and to end at one.

The potential extraction assigned to rooted compartment `i` is

```text
S_p,i = (f_i+1 - f_i) T_p
```

so, apart from representation precision, the sum of potential compartment extraction equals the potential transpiration supplied to the root process.

If there are no rooted compartments, or if potential transpiration is below the process's negligible-demand threshold, the evaluator exits with zero extraction rather than consuming unnecessary hydraulic/root-distribution state.

## Drought-only Feddes reduction

The frozen Status-A review baseline does **not** document the complete historical Feddes stress function. The admitted root process implements only its drought branch.

The critical drought threshold `h3` varies with potential transpiration. With configured low-demand and high-demand thresholds `h3L` and `h3H`, and demand breakpoints `ADCRL` and `ADCRH`, the process uses:

```text
T_p < ADCRL:
    h3 = h3L

ADCRL <= T_p <= ADCRH:
    h3 = h3H + ((ADCRH - T_p)/(ADCRH - ADCRL)) (h3L - h3H)

T_p > ADCRH:
    h3 = h3H
```

For local pressure head `h_i` and wilting threshold `h4`, the drought reduction factor is

```text
alpha_dry = 0                              for h_i < h4
alpha_dry = (h4 - h_i)/(h4 - h3)          for h4 <= h_i <= h3
alpha_dry = 1                              for h_i > h3
```

Actual compartment extraction is then

```text
S_a,i = alpha_dry S_p,i
```

and actual uptake is the sum over rooted compartments.

## Water-balance meaning

`S_a,i` is a nonnegative sink magnitude. It enters the soil-water balance once as root extraction. The reported actual transpiration/uptake total is attribution of that same physical withdrawal, not a second mass term.

Potential uptake, drought reduction and actual uptake are useful reconciliation diagnostics:

```text
potential uptake = actual uptake + drought reduction
```

subject to floating-point representation.

For the distinction between sink magnitudes, hydraulic flux signs and normalized verification accounting, see [Water balance, signs and units](water-balance-and-conventions.md).

## Process-local numerical character

The restricted ET and root-uptake evaluators are algebraic process calculations. They do not introduce an independent PDE discretisation, Newton solve, adaptive time-step controller or commit rule.

Root extraction is evaluated on the existing soil compartments and consumed by the Richards water-state advancement. Whether a water-state candidate is accepted, retried or committed remains the responsibility of the hydraulic/transaction execution path.

## What is explicitly outside this claim

This page does not admit or imply:

- wet-end or oxygen-stress branches of the broader Feddes formulation;
- salinity stress;
- compensation between rooted compartments;
- process-based root hydraulics;
- arbitrary within-step crop/root-distribution evolution;
- a broader crop-lifecycle model;
- alternative historical ET methods or interception routes;
- an independent root-water numerical solver.

Those capabilities require their own scientific, implementation and qualification authority before they can be described as current SWAP5 behaviour.

## Traceability

The scientific lineage and bounded historical formulation are recorded by F-DOC18. The frozen implementation postimage contains:

- `src/process/mod_reference_et_demand_process.f90`;
- `src/process/mod_root_water_uptake_process.f90`.

For current Status-A admission and preservation claims, use [Theory, code and evidence traceability](../status-a/TRACEABILITY.md). Historical source pins establish provenance but do not replace the current acceptance chain.
