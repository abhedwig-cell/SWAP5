# F-PE-ELASTIC72B — local synthetic identifiability preflight result

Date: 2026-09-30

Status: OFFLINE_PREFLIGHT_PASS

No GitHub Action was used.

## Purpose

Test whether the estimator

`Ss_skeleton ~= -d(epsilon_z)/dH`

can recover known synthetic coefficients under a simple high-frequency
extensometer/head observation geometry.

This is method evidence only. It is not peat calibration evidence.

## Frozen scenario

- 90 days;
- hourly sampling;
- layer thickness 2.0 m;
- characteristic groundwater-head amplitude 0.20 m;
- 500 Monte Carlo replicas per cell;
- independent Gaussian differential-displacement noise;
- noise scenarios: 0.1, 0.5 and 1.0 mm.

## Key results

For true `Ss = 1e-4 m^-1 = 1e-6 cm^-1`:

- 0.1 mm noise:
  median 1.002e-4 m^-1,
  95% empirical interval 8.61e-5 .. 1.16e-4,
  positive estimates 100%;

- 0.5 mm noise:
  median 1.037e-4 m^-1,
  interval 3.76e-5 .. 1.76e-4,
  positive estimates 100%;

- 1.0 mm noise:
  median 1.023e-4 m^-1,
  interval -4.12e-5 .. 2.40e-4,
  positive estimates 91.4%.

For true `Ss = 3e-4 m^-1 = 3e-6 cm^-1`, close to the magnitude of the
qualified mineral BOFEK median:

- 0.1 mm noise:
  median 3.006e-4 m^-1,
  interval 2.845e-4 .. 3.154e-4;

- 0.5 mm noise:
  median 3.006e-4 m^-1,
  interval 2.237e-4 .. 3.700e-4;

- 1.0 mm noise:
  median 3.007e-4 m^-1,
  interval 1.578e-4 .. 4.382e-4.

## Interpretation

The estimator is numerically identifiable at the synthetic geometry for
coefficients in the existing ELAS magnitude range when differential displacement
precision and groundwater excitation are adequate.

The experiment also shows that detectability is controlled by the combination
of:
- layer thickness;
- head-excursion amplitude;
- duration/sample count;
- differential anchor precision.

Therefore raw NOBV data access should first establish actual sensor precision,
anchor geometry, saturation margin and usable head excursions before any field
coefficient is estimated.

## Decision

`OFFLINE_IDENTIFIABILITY_METHOD_PLAUSIBLE`.

Advance to data-access/source audit only.

No physical peat Ss value is inferred by this result.
