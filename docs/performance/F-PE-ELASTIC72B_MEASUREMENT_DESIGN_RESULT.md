# F-PE-ELASTIC72B — offline measurement-design result

Date: 2026-09-30

Status: OFFLINE_MEASUREMENT_DESIGN_PASS

No GitHub Action was used.

## Purpose

Translate the ELASTIC72B identifiability relation into concrete observational
requirements for NOBV/Deltares extensometer data.

Primary relation:

`Ss_skeleton ~= -d(epsilon_z)/dH`.

For an anchor-bounded layer of thickness L and differential-displacement noise
sigma_z, the strain-noise scale is approximately:

`sigma_epsilon = sigma_z / L`.

For ordinary least-squares slope estimation, the idealized slope standard error
is:

`SE(Ss) ~= sigma_epsilon / sqrt(sum((H-Hmean)^2))`.

This result is a measurement-design calculation, not field calibration.

## Zegveld reference interval

Public NOBV reporting identifies a saturated peat interval of approximately:

`1.20 .. 4.49 m below surface`

in the parcel-16 reference extensometer.

Approximate bounded thickness:

`L = 3.29 m`.

The same reporting describes large seasonal reversible deformation strongly
related to groundwater dynamics.

## Frozen design scenario

Illustrative high-frequency design:
- layer thickness: 3.29 m;
- duration: 90 days;
- hourly observations;
- groundwater signal represented by a 30-day sinusoid plus a smaller 7-day
  component;
- characteristic primary head amplitude: 0.20 m.

Differential displacement-noise scenarios:
- 0.1 mm;
- 0.5 mm;
- 1.0 mm.

The reported limits below are idealized two-sided 95% zero-slope detection
thresholds (`1.96 * SE`).

## Results for L=3.29 m, head amplitude=0.20 m

0.1 mm displacement noise:
- threshold approximately `8.69e-8 cm^-1`.

0.5 mm displacement noise:
- threshold approximately `4.35e-7 cm^-1`.

1.0 mm displacement noise:
- threshold approximately `8.69e-7 cm^-1`.

Thus an Ss around `1e-6 cm^-1` is, in the idealized geometry, statistically
resolvable even with approximately 1 mm independent differential-displacement
noise.

An Ss around the qualified mineral BOFEK median
(`~2.84e-6 cm^-1`) is comfortably above these idealized detection limits.

## Sensitivity to groundwater excitation

At 0.5 mm noise and L=3.29 m:

- 0.05 m head amplitude:
  threshold approximately `1.74e-6 cm^-1`;
- 0.10 m:
  approximately `8.69e-7 cm^-1`;
- 0.20 m:
  approximately `4.35e-7 cm^-1`;
- 0.40 m:
  approximately `2.17e-7 cm^-1`.

Therefore cycle selection must prefer periods with material groundwater-head
excursion. Very small head cycles can become information-poor even when the
extensometer itself is precise.

## Scientific interpretation

The likely limiting problem for the Zegveld route is not raw signal amplitude.

The harder questions are physical identifiability:
- is the complete anchor-bounded layer saturated throughout the selected cycle;
- does phreatic head adequately represent pore-pressure change across the full
  deep layer;
- is the response quasi-static or meaningfully lagged;
- can reversible poroelastic strain be separated from creep/consolidation;
- are anchor errors independent, correlated or affected by common reference
  movement;
- are thin clay intercalations material to the inferred effective layer Ss.

These must be addressed before treating a slope as a peat constitutive
parameter.

## Decision

Classification:

`NOBV_MEASUREMENT_GEOMETRY_POTENTIALLY_RESOLVING_FOR_ELAS_MAGNITUDES`.

Advance only with raw multi-anchor and groundwater time series.

No published-figure digitization or inferred peat Ss is authorized by this
result.
