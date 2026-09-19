# HYDRO-MEMORY Stage 0 Numerical Accuracy Governance v1

**Status:** PROJECT_GOVERNANCE_APPROVED  
**Effective date:** 2026-09-19  
**Scope:** HYDRO-MEMORY Stage 0 research only

## 1. Purpose

This document fixes the numerical groundwater-head accuracy requirement for HYDRO-MEMORY Stage 0 before any ACC01 feasibility or timestep-acceptance result is inspected.

The rule is a research-methods requirement. It is not a universal SWAP5 default, a regulatory threshold, a hydrological impact threshold, a calibration statistic, or a value inferred from SWAP5 numerical behaviour.

## 2. Frozen Stage 0 experimental resolution

The Stage 0 groundwater-depth treatments are:

- 0.8 m;
- 1.2 m;
- 1.6 m;
- 2.0 m;
- 2.5 m;
- 3.0 m;
- 4.0 m below the reference surface.

The smallest prescribed separation between neighbouring groundwater-depth treatments is therefore 0.4 m = 40 cm.

Stage 0 uses one synthetic one-dimensional vertical column with the intermediate soil as the primary soil. The drought forcing is 30 days with precipitation 0 mm d-1 and potential transpiration 4 mm d-1. Recovery is 60 days with precipitation 5 mm d-1 and potential transpiration 3 mm d-1. Root depth is fixed at 0.60 m.

The numerical accuracy rule below is tied to this experimental design only.

## 3. Quantity of interest

The governed numerical quantity of interest is **GROUNDWATER_HEAD** at the SWAP-groundwater coupling interface over the complete 90-day Stage 0 drought-recovery experiment.

Groundwater drawdown and recovery diagnostics may be derived from this head trajectory, but this version of the accuracy contract governs the head trajectory itself.

## 4. Governed accuracy claims

### 4.1 Application prediction-error requirement, claim HM-ACC-APP-001

For HYDRO-MEMORY Stage 0, the maximum absolute numerical groundwater-head prediction error attributable to the coupled numerical calculation shall be no greater than **1% of the smallest prescribed groundwater-depth treatment separation**.

With a minimum treatment separation of 40 cm:

[
H_{app}=0.01\times40\;\mathrm{cm}=0.4\;\mathrm{cm}.
]

Thus the governed application requirement is:

[
\boxed{H_{app}=0.4\;\mathrm{cm}}
]

This criterion is adopted prospectively so that numerical head error is at least two orders of magnitude smaller than the smallest controlled groundwater-depth contrast in the Stage 0 design.

It is explicitly a numerical prediction-error acceptance rule. It is not a claim that 0.4 cm is a physically important groundwater change.

### 4.2 Temporal allocation requirement, claim HM-ACC-TEMP-001

A fixed **25%** of the Stage 0 groundwater-head numerical error allowance is allocated to time discretisation before any ACC01 temporal-indicator result is used.

Therefore:

[
A_{temporal}=0.25
]

and

[
H_{temporal}=H_{app}A_{temporal}
             =0.4\times0.25
             =0.1\;\mathrm{cm}.
]

Thus the governed model temporal-indicator budget is:

[
\boxed{H_{temporal}=0.1\;\mathrm{cm}}
]

The remaining 75% is intentionally not reassigned here. It remains available for coupling-interface error and other numerical contributions that require their own separately governed allocation.

The temporal allocation is an error-budget rule, not a timestep prescription. SWAP5 may adapt its timestep to meet this budget, but observed timestep behaviour may not be used to change the budget.

## 5. Independence from SWAP5 numerical behaviour

Neither claim 4.1 nor claim 4.2 is derived from:

- an observed SWAP5 timestep;
- a solver convergence tolerance;
- a step-doubling or temporal-indicator magnitude;
- a coupling corrector difference;
- calibration RMSE or another fit statistic;
- model-generated uncertainty;
- a physical-impact or monitoring threshold.

In particular, the previously observed diagnostic normalized temporal indicator under a 1e-5 cm probe budget is not used to select either governed value.

If the frozen values cannot be met, ACC01 fails or the numerical method/schedule must be improved. The values may not be relaxed after inspecting model behaviour.

## 6. Provenance and claim separation

The application and temporal rules are distinct clause-level claims in this same governed document.

- Application claim ID: **HM-ACC-APP-001**
- Temporal claim ID: **HM-ACC-TEMP-001**
- Application provenance ID: **590201**
- Temporal provenance ID: **590202**
- Contract ID: **590200**
- Contract version: **1**

The exact UTF-8 bytes of this document are the evidence source for both claims. The packet that instantiates the F-GC13 governance schema must record the SHA-256 digest of these exact bytes and verify the content match before positive admission.

## 7. Claim boundary

This document governs only HYDRO-MEMORY Stage 0 numerical accuracy.

It does not:

- qualify model structural uncertainty;
- qualify parameter or forcing uncertainty;
- establish a general SWAP5 accuracy default;
- relax hard mass conservation;
- admit a production SWAP-MODFLOW application;
- authorize HYDRO-MEMORY Stage 0 until the numerical capability gates are also passed.


## 8. ACC02 groundwater-interface allocation, claim HM-ACC-IFACE-001

Before any HYDRO-MEMORY groundwater-coupling feasibility result is inspected, a separate **25%** of the Stage 0 groundwater-head numerical error allowance is assigned to the accepted SWAP-groundwater interface head residual.

The allocation is deliberately symmetric with the already governed temporal share:

- temporal discretisation allocation: 25%;
- groundwater-interface convergence allocation: 25%;
- remaining unallocated numerical guard band: 50%.

The unallocated 50% is intentionally not reassigned here. It remains reserved for other numerical contributions that may later require separate qualification, including spatial discretisation and solver/coupling components not already covered by the two governed shares.

Therefore:

[
A_{interface}=0.25
]

and, with (H_{app}=0.4) cm,

[
H_{interface}=H_{app}A_{interface}
             =0.4\times0.25
             =0.1\;\mathrm{cm}
             =0.001\;\mathrm{m}.
]

Thus the governed groundwater interface head-residual tolerance is:

[
\boxed{H_{interface}=0.001\;\mathrm{m}}
]

This is an explicit numerical coupling-accuracy allocation. It is not inferred from a predictor/corrector residual, an observed groundwater response, a coupling timestep, a convergence history, or a physical groundwater threshold.

If the coupled runtime cannot satisfy this tolerance, the capability test fails or the numerical coupling method/window schedule must improve. This value may not be relaxed after inspecting coupling behaviour.

- Interface claim ID: **HM-ACC-IFACE-001**
- Interface binding provenance ID: **590203**
- Interface policy ID: **590210**
- Interface policy version: **1**
