# CSR-04 storage-partition derivation

Date: 2026-09-20

Status: **SCIENTIFIC DERIVATION CHECKPOINT, IMPLEMENTATION NOT AUTHORIZED**

Live canonical reconciliation: `integration/f-ci-canonical@3a815edda7cf5e155272b68ae49d440fd5db9138`.

## 1. Purpose

This note derives the minimum coupled control-volume statement needed to decide whether the existing SWAP finite-window response coefficient `u` can be combined physically with MODFLOW STO without double counting.

It does not alter F-GC30/F-GC33 algebra and does not introduce a new coupling method.

## 2. Separate control volumes

Let the SWAP column control volume have water storage `S_s`, external non-interface source/sink integral `E_s`, and lower-face transfer `Q_i`.

Choose one sign convention for the derivation: `Q_i > 0` means water leaves SWAP and enters the MODFLOW groundwater control volume.

Then over one coupling window:

`Delta S_s = E_s - Q_i`.

Let the MODFLOW groundwater control volume have storage `S_g`, non-interface groundwater source/sink integral `E_g`, and receive the same interface transfer:

`Delta S_g = E_g + Q_i`.

Adding the two equations gives:

`Delta(S_s + S_g) = E_s + E_g`.

The interface transfer cancels. This is the physical invariant the coupled implementation must preserve.

## 3. What the existing SWAP response represents mathematically

The current predictor perturbs prescribed lower-boundary flux from one accepted SWAP origin and obtains the terminal lower-face head response:

`dH_b/dq_b`.

The admitted coefficient is:

`u = DeltaT / (dH_b/dq_b)`.

Therefore:

`u/DeltaT = dq_b/dH_b`

for the local finite-window inverse response used by the predictor, subject to the pinned sign convention.

The dimensions are consequently those of a flux-to-head slope. When inserted into the MODFLOW affine boundary term, `u/DeltaT` behaves algebraically like a conductance/storage-rate coefficient. This dimensional fact does **not** by itself identify `u` with a physical aquifer storage coefficient.

The finite-window map already contains the response of all SWAP state variables that change during the prescribed-qbot replay. Hence `u` is a condensed dynamic response of the SWAP column, not a separately measured water volume.

## 4. MODFLOW STO is different authority

MODFLOW STO contributes transient storage associated with the GWF cells through specific storage and, for convertible cells, specific yield according to the selected STO formulation.

Thus the groundwater equation already has an independently defined derivative of groundwater stored water with respect to head.

The SWAP affine package term is a boundary/exchange response. It may be combined with STO only if its head derivative represents the derivative of **interface transfer conditional on the SWAP control volume**, rather than a second booking of the same groundwater storage represented by STO.

## 5. Key distinction

The physically relevant question is therefore not:

> Is `u` a storage coefficient?

but:

> Which state-volume response has been Schur-condensed into `dq_i/dH_b`, and is any of that same water volume already represented by the MODFLOW STO derivative?

This resolves an important ambiguity in earlier wording. `u` is storage-like in the coupled matrix but must not be labelled a physical storage coefficient without a control-volume derivation.

## 6. Candidate physical partition consistent with the current architecture

The cleanest non-overlap contract is:

- SWAP owns all water storage represented inside the finite SWAP column down to its fixed lower face;
- MODFLOW owns groundwater storage in its GWF control volume below/outside that coupling plane;
- the shared quantity is only the lower-face transfer `Q_i`;
- the derivative supplied by SWAP to MODFLOW is the head sensitivity of that interface transfer after eliminating SWAP internal states.

Under this contract, the SWAP response slope is a boundary Jacobian/Schur-complement term. It is **not** additional MODFLOW STO.

This formulation is mathematically coherent only when the MODFLOW cell storage volume does not also include the same physical saturated material represented as SWAP column storage.

## 7. Why current topology cannot yet prove the candidate partition

The present tile-to-cell topology maps a SWAP column to a MODFLOW cell but does not define a vertical control-volume cut that excludes the SWAP-represented saturated storage from the MODFLOW STO volume.

The existing identity head transfer also does not create such a partition. Equal hydraulic head at an interface is compatible with distinct control volumes, but it does not establish them.

Therefore the candidate partition above cannot yet be promoted to production authority.

## 8. Two admissible ways to close CSR-04

### A. Non-overlapping geometric partition

Define the SWAP lower face as a true model-domain interface and configure MODFLOW STO only for the groundwater volume not represented by SWAP.

Then F-GC30/F-GC33 can be interpreted as condensed interface response, with no overlap correction.

This is conceptually the cleanest route, but may not match the intended regional MODFLOW discretization where the mapped cell extends through material also represented by the SWAP column.

### B. Overlapping models with explicit mathematical correction

If SWAP and MODFLOW intentionally represent overlapping saturated storage, derive the duplicated storage derivative and remove it exactly once from the assembled coupled equation.

No such correction is currently specified or qualified in SWAP5. Implementing one now would be new coupling physics/architecture and is not authorized by this workunit.

## 9. Qualification that can discriminate the issue

A decisive CSR-04 experiment should use a closed or tightly controlled one-column/one-cell system with nonzero transient storage and no confounding drainage/root/atmospheric terms.

Required observations per coupling window:

- accepted SWAP storage change;
- accepted MODFLOW STO storage change;
- accepted interface transfer;
- all external fluxes;
- combined-system residual;
- terminal SWAP lower-face head and MODFLOW head;
- F-GC30 response `u` and the affine package slope.

Run at least:

1. SWAP-only perturbation to verify `Delta S_s = E_s-Q_i`;
2. MODFLOW-only transient storage perturbation to verify its STO balance;
3. coupled case with the intended partition;
4. sensitivity to vertical overlap/partition choice if the production topology permits overlap.

The primary acceptance condition is component and combined water balance, not merely head convergence or interface residual.

## 10. Decision

The derivation narrows CSR-04 substantially:

- `u` should be treated as a condensed finite-window interface-response coefficient, not automatically as a physical storage coefficient;
- MODFLOW STO remains groundwater-volume storage authority;
- simultaneous use is physically valid only under an explicit non-overlap partition or an explicit overlap correction;
- current SWAP5 topology does not yet establish either.

Disposition remains:

`CSR04_BLOCKED_SCIENTIFIC_STORAGE_PARTITION_AUTHORITY`.

The next admissible implementation step is **not** to alter F-GC30/F-GC33. It is to materialize an explicit vertical storage-domain/topology contract and a controlled nonzero-storage qualification fixture. A realistic Hupsel/E7 rerun remains premature.
