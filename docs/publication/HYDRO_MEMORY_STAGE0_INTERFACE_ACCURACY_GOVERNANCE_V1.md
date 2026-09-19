# HYDRO-MEMORY Stage 0 Groundwater-Interface Accuracy Governance v1

**Status:** PROJECT_GOVERNANCE_APPROVED  
**Effective date:** 2026-09-19  
**Scope:** HYDRO-MEMORY Stage 0 research only

## 1. Purpose

This document governs the numerical head-residual tolerance at the accepted SWAP-groundwater coupling interface for HYDRO-MEMORY Stage 0.

It is a separate claim from the already qualified application head-error requirement and temporal allocation. It does not alter those claims or their source document.

## 2. Existing governed authority

HYDRO-MEMORY Stage 0 already fixes:

- application numerical groundwater-head error requirement: H_app = 0.4 cm;
- temporal allocation fraction: A_temporal = 0.25;
- temporal head-error budget: H_temporal = 0.1 cm.

Those values remain unchanged.

## 3. Interface allocation claim HM-ACC-IFACE-001

Before any groundwater-coupling feasibility result is inspected, a separate 25% of the Stage 0 application numerical head-error allowance is allocated to accepted interface head residual.

The allocation is deliberately symmetric with the temporal share:

- temporal discretisation: 25%;
- groundwater-interface convergence: 25%;
- unallocated numerical guard band: 50%.

The remaining 50% is intentionally not assigned here. It remains available for other numerical contributions requiring separate qualification, including spatial discretisation and numerical components outside the temporal and interface contracts.

Thus:

A_interface = 0.25

and:

H_interface = H_app * A_interface
            = 0.4 cm * 0.25
            = 0.1 cm
            = 0.001 m.

The governed coupling-interface head-residual tolerance is therefore **0.001 m**.

## 4. Independence from model behaviour

The 25% interface allocation is a prospective research-methods rule. It is not derived from:

- an observed predictor/corrector head residual;
- an observed groundwater response;
- a coupling window duration;
- a solver or retry history;
- a SWAP temporal-indicator magnitude;
- a calibration statistic;
- model-generated uncertainty;
- a physical-impact or monitoring threshold.

If the coupled runtime cannot satisfy 0.001 m, the capability test fails or the numerical coupling/window strategy must improve. The governed tolerance may not be relaxed after inspecting coupling behaviour.

## 5. Canonical mapping

The claim is intended for the already admitted F-GC22 groundwater accuracy binding:

- interface_allocation_fraction = 0.25;
- groundwater head policy tolerance = H_app * 0.01 m/cm * 0.25 = 0.001 m;
- temporal + interface allocation = 0.50 <= 1.00.

Identifiers:

- claim ID: **HM-ACC-IFACE-001**
- binding provenance ID: **590203**
- head-convergence policy ID: **590210**
- policy version: **1**

The binding provenance ID is distinct from application provenance 590201 and temporal provenance 590202.

## 6. Claim boundary

This document does not:

- change H_app, A_temporal or H_temporal;
- allocate the remaining 50% numerical guard band;
- relax hard mass conservation;
- set a solver tolerance;
- set a coupling-window duration;
- establish a universal SWAP5 or MODFLOW6 default;
- authorize the 90-day Stage 0 experiment by itself.
