# PUB-GC E7 realistic-case selection and readiness

## Status

**STANDALONE_SELECTION_FROZEN — READY_FOR_COUPLED_EXECUTION**

Date: 2026-09-18.

Canonical basis for the frozen standalone selection:

`integration/f-ci-canonical@12beef3e91f90f88b101c13af72cd216bccc63e3`

No E7 coupled output was calculated or inspected before the dates and groundwater fixture below were frozen.

## M1 prerequisite is closed

The former external-asset blocker is superseded by canonical evidence.

- exact whole-Hupsel typed-adapter qualification: **PASS**;
- M1-C3 canonical admission: PR #313;
- M1 formal closeout: PR #316;
- current M1 verdict: `M1_CLOSED_CURRENT_CANONICAL`;
- accepted historical intervals: **32,518**;
- accepted-interval fallback: **none**;
- exact distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- exact nested source SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The exact raw distribution was also recovered from the existing Library. No new user upload is required.

## Standalone Hupsel gate

The official 2002–2004 Hupsel run was rebuilt using GNU Fortran 14.2.0 and the already admitted F-APP03 standalone GNU preprocessing method.

The daily observation trace is accepted only because the run remained scientifically identical to the admitted whole-Hupsel authority:

```text
normalized result.bal:
a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7

normalized result.blc:
1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c
```

The trace contains **1,096** complete civil days from 2002-01-01 through 2004-12-31. No controlling Hupsel authority documents a spin-up interval, so the preregistered rule removes no days.

## Frozen selection metric

For every eligible day:

```text
I = precipitation + irrigation
E = actual root uptake + soil evaporation + pond evaporation + interception evaporation
D = drainage outflow magnitude
S = |storage_end - storage_start|

Phi = 0.25 * (R_I + R_E + R_D + R_S)
```

Ranks use mean zero-based rank divided by `N-1`; ties receive the mean rank.

Population median `Phi = 0.5067922374429223`.

## Frozen dates

### Median-dynamics control

**2003-06-17**

```text
I       = 0.20000000000000007 cm
E       = 0.17917240345831503 cm
D       = 0.022586870162615704 cm
|dS|    = 0.001759267628429484 cm
R_I     = 0.7374429223744292
R_E     = 0.6831050228310502
R_D     = 0.6018264840182649
R_S     = 0.0045662100456621
Phi     = 0.5067351598173516
```

### High-dynamics day

**2003-05-20**

```text
I       = 2.2300000000000177 cm
E       = 0.11468910769777912 cm
D       = 0.9069694038599311 cm
|dS|    = 1.2083413574577264 cm
R_I     = 0.9917808219178083
R_E     = 0.5762557077625571
R_D     = 0.9954337899543378
R_S     = 0.9689497716894977
Phi     = 0.8831050228310502
```

The dates are immutable for E7 and cannot be replaced after observing coupled behaviour.

## Frozen groundwater fixture

A targeted canonical search before the first E7 coupled run found no independently authoritative Hupsel MODFLOW/aquifer model.

The preregistered fallback therefore applies: reuse the already-qualified F-GC44 conceptual MODFLOW6 fixture without calibration against E7 output.

```text
grid:       1 layer × 1 row × 3 columns
delr/delc:  1 m / 1 m
top:        0 m
bottom:    -2 m
SWAP cell:  central cell (0,0,1)
K:          1 m/day
ss:         0.02 1/m
sy:         0.15
icelltype:  1
initial H:  H_ref
left CHD:   H_ref + 0.002 m
right CHD:  H_ref - 0.002 m
area:       1 m²
```

The official Hupsel profile is exactly 200 cm deep, so its lower coupling plane is `z_bottom=-2.00 m` relative to the surface datum. The F-GC44 vertical datum therefore requires no artificial depth shift.

MODFLOW6 uses the already-qualified Newton formulation and IMS settings; they are not retuned for E7.

Because the groundwater component is conceptual rather than a calibrated Hupsel aquifer, E7 is described as a **real-forcing hydrological demonstration**, not regional Hupsel groundwater validation.

## Durable selection evidence

- `PUB_GC_E7_STANDALONE_SELECTION_RESULT.json`
- `PUB_GC_E7_SELECTED_DAYS.csv`

Local full-population evidence is identified by:

```text
daily metrics SHA-256:
d532d07a34ad5bdd98730373330bca4b870439eec6783bf9f25b8d58c1906fb3

scored 1096-day table SHA-256:
016e6d14a23d5cd5eb0f464167a50f232106cd7cd28c16f11478b04b1d237e6e
```

## Next permitted action

Execute the already-preregistered loose/sequential and production-strong comparisons for **only** these two dates, preserving exact event-aligned Hupsel application intervals.

Do not:

- replace either date;
- calibrate groundwater parameters to the observed coupling difference;
- merge or shorten windows after a failure;
- relax solver, temporal, mass or coupling tolerances;
- reinterpret a component-domain failure as outer-coupling divergence.
