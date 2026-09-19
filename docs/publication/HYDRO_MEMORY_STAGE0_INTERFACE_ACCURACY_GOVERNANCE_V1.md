# HYDRO-MEMORY Stage 0 Coupling-Interface Accuracy Governance v1

**Status:** PROJECT_GOVERNANCE_APPROVED  
**Effective date:** 2026-09-19  
**Scope:** HYDRO-MEMORY Stage 0 research only

## 1. Purpose

This document allocates part of the already governed HYDRO-MEMORY Stage 0 numerical groundwater-head error allowance to convergence of the SWAP-groundwater coupling interface.

It does not change the Stage 0 application requirement. The parent contract remains:

- groundwater-head numerical application requirement: `H_app = 0.4 cm`;
- temporal allocation: `A_temporal = 0.25`;
- temporal budget: `H_temporal = 0.1 cm`.

The interface allocation is fixed before any HYDRO-MEMORY coupling-feasibility result is inspected.

## 2. Interface allocation claim HM-ACC-INT-001

The Stage 0 coupling-interface head residual is allocated **25%** of the governed application head-error allowance:

[
A_{interface}=0.25.
]

Therefore:

[
H_{interface}=H_{app} A_{interface}
             =0.4\times0.25
             =0.1\;\mathrm{cm}
             =0.001\;\mathrm{m}.
]

Thus the governed coupling-head convergence tolerance is:

[
\boxed{H_{interface}=0.001\;\mathrm{m}}.
]

## 3. Allocation rationale

Stage 0 treats temporal discretisation and coupling-interface convergence as two separately controlled numerical contributions to the groundwater-head quantity of interest.

Each receives one quarter of the application numerical head-error allowance:

[
A_{temporal}=A_{interface}=0.25.
]

Their bookkeeping allocation therefore totals 0.50 of `H_app`. The other 0.50 is deliberately **not allocated** in Stage 0 and remains a reserve for spatial discretisation, nonlinear/linear solution error and other numerical contributions that are not independently quantified here.

This allocation is intentionally conservative. It does not assume that individual numerical errors are statistically independent and does not claim that their realised errors add linearly. It is an ex-ante acceptance-budget partition.

## 4. Independence from SWAP5 numerical behaviour

The 25% interface allocation is not derived from:

- an observed predictor/corrector residual;
- an observed number of coupling iterations;
- an observed MODFLOW or SWAP head difference;
- a solver convergence tolerance;
- a temporal-indicator value;
- calibration residuals;
- model-generated uncertainty;
- a hydrological impact threshold.

If the resulting 0.001 m interface tolerance is not feasible, the coupling route fails Stage 0 feasibility or must be improved. This allocation may not be relaxed after inspecting coupling behaviour.

## 5. Governance identity

- Interface claim ID: **HM-ACC-INT-001**
- Interface binding provenance ID: **590203**
- Groundwater head policy ID: **590210**
- Groundwater head policy version: **1**
- Parent application contract ID: **590200**
- Parent application contract version: **1**

The source bytes of this document and their repository blob identity are the authority for the interface-allocation claim.

## 6. Claim boundary

This document governs only the numerical coupling-interface head residual for HYDRO-MEMORY Stage 0.

It does not:

- relax hard mass conservation;
- convert the 0.001 m value into a physical-impact threshold;
- qualify spatial discretisation error;
- qualify parameter, forcing or structural uncertainty;
- establish a general SWAP5 or MODFLOW tolerance;
- authorize the 90-day Stage 0 experiment before executable coupling feasibility is demonstrated.
