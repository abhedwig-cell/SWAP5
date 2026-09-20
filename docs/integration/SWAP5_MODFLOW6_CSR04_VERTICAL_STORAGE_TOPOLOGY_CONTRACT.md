# CSR-04 vertical storage-topology contract

Date: 2026-09-20

Status: **PREREGISTERED AUTHORITY REQUIREMENT — NO PRODUCTION PHYSICS CHANGE**

Live canonical observed during this checkpoint: `integration/f-ci-canonical@1caa431002d5c128c73cfcfbd31af4cc39ee9f12`.

## 1. Purpose

CSR-04 cannot be closed by changing the predictor algebra. It requires the application topology to state which physical water-storage domain belongs to SWAP and which belongs to MODFLOW.

This document defines the minimum metadata and invariants required before implementation or realistic qualification.

## 2. Required topology objects

A coupled tile/cell mapping must identify:

### SWAP storage domain

- SWAP column identifier;
- surface elevation/datum;
- fixed lower-face elevation `z_b`;
- statement that SWAP owns all water storage integrated by the column state above that lower face;
- whether any saturated column thickness is represented by SWAP during the application.

### MODFLOW storage domain

- mapped GWF model/cell identifier;
- cell top and bottom or equivalent vertical support;
- STO activity/type for that cell;
- statement of the physical groundwater volume to which STO applies.

### Coupling plane

- elevation/datum of the physical/computational exchange plane;
- head-transfer operator from MODFLOW state to SWAP lower-face trial head;
- area mapping between SWAP tile and GWF cell;
- interface-flux sign and unit convention.

## 3. Storage-partition enum

The application contract needs an explicit storage-partition declaration. Minimum admissible values:

- `NON_OVERLAPPING_VERTICAL_DOMAINS`
- `OVERLAPPING_WITH_EXPLICIT_CORRECTION`
- `UNRESOLVED`

Production two-way groundwater coupling must fail closed on `UNRESOLVED`.

`OVERLAPPING_WITH_EXPLICIT_CORRECTION` is reserved. No correction law is currently authorized.

## 4. Non-overlap invariant

For `NON_OVERLAPPING_VERTICAL_DOMAINS`, the application must provide enough geometry/authority to assert that no physical storage volume represented in the SWAP finite-window state response is independently booked by MODFLOW STO.

This is a physical-volume invariant, not merely an equality or inequality of model-layer coordinates. Different discretizations may require an explicit application mapping.

The identity head-transfer law does not prove this invariant.

## 5. Balance invariant

For accepted window `n`, with `Q_i>0` from SWAP to MODFLOW:

`Delta S_SWAP = E_SWAP - Q_i + r_SWAP`

`Delta S_MF   = E_MF   + Q_i + r_MF`

and therefore:

`Delta S_SWAP + Delta S_MF = E_SWAP + E_MF + r_SWAP + r_MF`.

The qualification must report the two component residuals and the combined residual. Interface cancellation is mandatory.

## 6. Response invariant

The F-GC30/F-GC33 coefficient must be recorded as response metadata:

`J_i = u/DeltaT = dq_i/dH_b`

under the pinned conventions.

It must not be added to a storage ledger as a water volume. Its physical admissibility follows from the declared storage partition and the finite-window SWAP response, not from naming it storage.

## 7. Minimal controlled qualification fixture

Before realistic E7/Hupsel use, add a one-SWAP-column/one-GWF-cell fixture with:

- nonzero MODFLOW STO;
- nonzero SWAP storage change;
- explicit coupling-plane geometry;
- no root uptake;
- no drainage;
- no precipitation/evaporation unless required to generate a controlled perturbation;
- one declared external perturbation;
- complete component water budgets.

Required cases:

1. `SWAP_COMPONENT`: verify SWAP component storage/exchange balance.
2. `MODFLOW_COMPONENT`: verify GWF STO/external-flow balance.
3. `COUPLED_NON_OVERLAP`: verify interface equality and combined cancellation with both storages active.
4. `PARTITION_NEGATIVE`: deliberately unresolved/overlapping metadata must fail admission rather than silently run.

## 8. Required evidence fields

Persist for each accepted window:

- `delta_storage_swap`;
- `delta_storage_modflow`;
- `interface_transfer_swap`;
- `interface_transfer_modflow`;
- `external_transfer_swap`;
- `external_transfer_modflow`;
- `component_residual_swap`;
- `component_residual_modflow`;
- `combined_residual`;
- `H_swap_bottom`;
- `H_modflow_interface`;
- `u`;
- `u_over_dt`;
- partition identifier and geometry provenance.

## 9. Admission sequence

1. topology schema only;
2. fail-closed validation;
3. controlled component fixture;
4. coupled non-overlap fixture;
5. sensitivity/negative fixture;
6. only then requalify realistic F-GC/PUB-GC evidence.

No drainage/root widening and no E7 rerun belongs before step 4.

## 10. Current disposition

The contract is now sufficiently specific to implement metadata and fail-closed validation without inventing new hydrological physics.

What remains scientifically unresolved is the **production application's actual vertical partition**: the repository does not yet establish that the mapped MODFLOW STO volume excludes the saturated storage represented inside the SWAP column.

Therefore:

`CSR04_CONTRACT_PREREGISTERED_PRODUCTION_PARTITION_UNRESOLVED`.

This narrows the previous blocker. Schema/validation and controlled qualification infrastructure can proceed; authentic production admission cannot.
