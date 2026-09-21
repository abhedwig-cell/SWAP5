# MODFLOW6 DSW numerical oracle: Newton storage smoothing

Date: 2026-09-21
Status: SOURCE-DERIVED RESEARCH ORACLE
MODFLOW authority: MODFLOW-ORG/modflow6 tag 6.8.0

## Observation

The DSW-01 constant-flux control with a convertible 1 m2 MODFLOW cell,
`Sy=0.20`, initial head 8.0 m and +0.010 m3/day input produced:

```
h = 8.049999949999998 m
```

instead of the unsmoothed physical value 8.05 m.

Tightening IMS tolerances did not change the result.

## Source derivation

In MODFLOW 6.8.0 `src/Model/GroundWaterFlow/gwf-sto.f90`, the STO package sets

```
satomega = DEM6 = 1e-6
```

when Newton is active, and evaluates convertible-cell saturation using
`sQuadraticSaturation(..., satomega)`.

In `src/Utilities/SmoothingFunctions.f90`, for an interior saturation away
from the top/bottom smoothing limbs:

```
av = 1 / (1-eps)
y  = av*br + 0.5*(1-av)
```

so

```
dy/dh = 1 / ((top-bot)*(1-eps)).
```

The specific-yield storage response therefore has the effective interior slope

```
Sy_eff = Sy / (1-eps).
```

For DSW-01:

```
eps = 1e-6
P   = 0.010 m
Sy  = 0.20

Delta h = P / Sy_eff
        = (P/Sy)*(1-eps)
        = 0.05 * 0.999999
        = 0.04999995 m

h1 = 8.04999995 m
```

This matches the live observation to floating-point precision.

## Consequence for the coupling testbank

Do not weaken the preregistered physical oracle.

Use two explicitly different numerical controls:

1. **unsmoothed physical control**: run the one-cell storage equation without
   Newton saturation smoothing; oracle is exactly 8.05 m;
2. **production-like Newton control**: retain Newton smoothing; source-derived
   oracle is 8.04999995 m.

The difference is a documented MODFLOW numerical regularization, not hydrologic
coupling error.

The DSW-01 current-u observation at exactly 8.0 m is five centimetres away from
the physical solution and is therefore categorically distinct from this
50-nanometre smoothing effect.

## Source boundary

This document describes MODFLOW 6.8.0 behavior only. If the MODFLOW version or
STO/Newton formulation changes, re-derive the numerical oracle from that
version's source.
