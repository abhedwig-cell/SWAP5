# F-PE-ELASTIC04 — typed per-layer ELAS architecture preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_RESULTS

## Purpose

Qualify the intended SWAP5 ownership model for elastic storage without changing production source.

The scientific value of ELAS and the software location of ELAS are separate questions. This workunit addresses only software ownership and exact semantics.

## Proposed typed contract

A production-shaped soil-hydraulic material configuration shall expose:

- `elastic_storage_active` as an explicit capability/configuration choice;
- `specific_elastic_storage(:)` in 1/cm, one value per active soil node/material layer.

The coefficient belongs to soil-hydraulic material authority, not `soil_water_numerical_config_t`.

## Semantics

When elasticity is inactive:
- current default B1.10-MvG provider behaviour must remain exact;
- current `dt*1e-7` saturated capacity fallback remains unchanged.

When elasticity is active:
- for `h >= 0`: `theta = theta_s + h * specific_elastic_storage`;
- for `h >= 0`: `C = specific_elastic_storage`;
- for `h < 0`: current MvG retention/capacity remains unchanged;
- conductivity remains governed by the existing MvG conductivity relation.

This is the exact corrected legacy ELAS constitutive meaning, with typed ownership replacing `cofgen(24)`.

## Gates

### A. inactive preservation
Across all 36 exact Staringreeks 2018 materials and a frozen head matrix, typed-inactive output must be bit-identical to the current default provider for theta, C and K.

### B. active legacy identity
Across all 36 materials and the same head matrix, typed-active ELAS=1e-6 must match the existing test-only legacy-`cofgen(24)` provider to tight floating-point identity.

### C. layer heterogeneity
A synthetic profile with node-varying ELAS must demonstrate independent per-node ownership. No first-node/global leakage is allowed.

### D. dynamic seed preservation
For B01, B12, O05 and O14 seed fixtures, typed-active and legacy-ELAS execution must produce identical solver status, work counters and physical outputs where the comparison run completes.

## Production boundary

This workunit is test-only.

It does not authorize:
- adding a production input keyword;
- changing the current default;
- assigning 1e-6 to all soils;
- deriving ELAS from MvG parameters;
- modifying production `src/**`.

A later production extraction may proceed only if these ownership/identity gates pass.
