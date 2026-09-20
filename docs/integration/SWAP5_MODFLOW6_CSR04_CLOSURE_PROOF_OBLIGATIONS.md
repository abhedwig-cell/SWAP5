# CSR-04 closure proof obligations

Date: 2026-09-20

Status: **SCIENTIFIC PROOF OBLIGATIONS — CONTROLLED QUALIFICATION NEXT**

## 1. Why equal exchange and equal interface head are necessary but not sufficient

The present coupled iteration enforces two powerful interface conditions at convergence:

1. transfer continuity: the water transfer leaving SWAP equals, under the pinned sign convention, the transfer entering MODFLOW;
2. hydraulic compatibility: in the current identity-transfer realization, the SWAP lower-face trial hydraulic head equals the selected MODFLOW hydraulic head.

These conditions establish a conservative and hydraulically compatible **interface**.

They do not by themselves establish that the union of the two model state spaces is a non-overlapping representation of the physical system.

A coupling can satisfy both interface conditions while the two component models independently store water in the same physical saturated volume. In that case the interface transfer still cancels exactly, yet the combined storage response can be wrong.

## 2. Three distinct conservation/compatibility statements

### P1 — interface mass continuity

For accepted window transfer `Q_i`:

`Q_i,SWAP + Q_i,MF = 0`

after sign/unit/area conversion.

This is already the central F-GC coupling residual/ledger property.

### P2 — interface hydraulic compatibility

For the current identity transfer:

`H_b,SWAP = H_i,MF`.

For a generalized transfer law:

`H_b,SWAP = T_H(H_MF,...)`.

This is a constitutive/interface condition, not a mass-balance proof.

### P3 — global storage closure

For non-overlapping component domains:

`Delta S_SWAP + Delta S_MF = E_SWAP + E_MF + residuals`.

P3 requires that `S_SWAP` and `S_MF` are additive physical storages. That additivity is not implied by P1 or P2.

Therefore P1 + P2 are necessary for the intended present coupling, but P3 is an independent proof obligation.

## 3. Counterexample showing insufficiency

Consider a saturated physical layer of storage change `Delta S_x` that is represented in both the lower saturated part of SWAP and in MODFLOW STO.

Suppose the coupled solver converges perfectly:

- SWAP exports `Q_i`;
- MODFLOW imports exactly `Q_i`;
- both use the same interface head.

The summed model budget still contains:

`Delta S_combined = ... + Delta S_x(SWAP) + Delta S_x(MF)`.

The duplicated storage term is unaffected by cancellation of `Q_i`.

Thus zero interface residual and equal head can coexist with physical double representation.

This is the exact reason CSR-04 cannot be closed by the existing interface convergence evidence alone.

## 4. What would constitute proof

For a declared non-overlap topology, sufficient evidence requires all of:

- P1 transfer continuity;
- P2 hydraulic compatibility under the declared head-transfer operator;
- component SWAP water-balance closure;
- component MODFLOW water-balance closure;
- an explicit storage-domain partition proving additivity of component storages;
- combined-system water-balance closure using those additive storages;
- perturbation evidence showing that changing MODFLOW STO changes only the MODFLOW-owned storage response and does not silently create a second booking of a SWAP-owned physical volume.

The final item is important: a single zero-residual run can hide a structural overlap. Controlled perturbations make the ownership observable.

## 5. Controlled experiment matrix

Keep geometry, SWAP hydraulic parameters, coupling window and external forcing fixed.

### Case A — steady/no MODFLOW storage response

Suppress transient MODFLOW storage response for the diagnostic fixture while retaining the interface solve. This isolates the SWAP-side finite-window response and verifies F-GC30/F-GC33 as an interface response.

### Case B — MODFLOW STO response active

Activate a known, nonzero MODFLOW storage response in the declared MODFLOW-owned domain. Verify the incremental groundwater storage term against the imposed head change and the MODFLOW component budget.

### Case C — coupled non-overlap

Run both responses simultaneously with a declared non-overlap partition. Verify P1, P2 and P3 and compare the combined response with A+B accounting.

### Case D — invalid/unresolved partition

Use identical numerical parameters but mark the physical partition unresolved. Admission must fail before execution. This verifies that a numerically convergent configuration cannot masquerade as scientifically admitted coupling.

## 6. Acceptance quantities

For every case report, in one common volume convention:

- SWAP initial/final storage;
- MODFLOW initial/final storage;
- SWAP external transfer;
- MODFLOW external transfer;
- SWAP interface transfer;
- MODFLOW interface transfer;
- interface mismatch;
- SWAP component residual;
- MODFLOW component residual;
- combined residual;
- lower-face/interface heads;
- predictor `u`;
- `u/DeltaT`.

Pass/fail thresholds must be preregistered from numerical precision and existing component-budget tolerances; they must not be chosen after observing results.

## 7. Scientific decision rule

If P1 and P2 pass but P3 fails, do **not** tune the coupling residual. Diagnose storage-domain ownership.

If all numerical balances pass but the physical partition remains unresolved, classify the case as numerically qualified but scientifically unadmitted.

If an explicit non-overlap partition plus component and combined budgets pass under controlled storage perturbation, CSR-04 may advance from authority blocker to production-topology requalification.

## 8. Consequence for current evidence

Existing evidence that accepted SWAP and MODFLOW exchange agree remains valid and valuable. Existing head compatibility remains valid for the identity-transfer topology.

Neither is superseded.

Their evidentiary scope is now bounded precisely: they prove the interface, not the additivity of the two storage state spaces.
