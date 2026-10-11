# PPA-WU05-MIGMAC01 canonical reconciliation result

Date: 2026-10-02
Status: QUALIFIED_ADMISSION_CANDIDATE_READY_FOR_CANONICAL_INTEGRATION
Canonical base: f7c261a7f059c91d4a0aac16e378351f293aa080
Qualified production postimage: 8f3f2d487fe177b74a14e0c5aa2942d25c342e09
Reconcile branch: reconcile/ppa-wu05-migmac01-canonical

## Reconciliation

The stale research branch was not merged wholesale. The admission candidate was
reconstructed canonical-first from the current canonical base.

Shared production files were semantically composed:

- src/legacy/b1_10_port/headcalc.f90 retains the admitted LOW03 resistive-bottom
  implementation and adds the qualified MIGMAC01 matrix-area, stable storage
  increment and source-backed short-step macropore semantics.
- src/solver/mod_soil_water_solver_contract.f90 retains the LOW03 typed Cauchy
  boundary contract and adds the MIGMAC01 matrix-area carrier and constitutive
  water-content-increment contract.
- src/runtime/mod_fmr_serialized_reference_backend.f90 retains current canonical
  LOW01/LOW03/LOW05 lower-boundary ownership, RFM composition and Bartholomeus
  oxygen application while adding the qualified MIGMAC01 matrix-area propagation,
  immutable covering parameters, matrix storage/temporal accounting and
  Reference root-extraction + macropore composition.

The other MIGMAC01 production files were unchanged by canonical since the
recorded migration base and were transferred exactly from the qualified research
postimage.

Canonical advanced once during the first qualification attempt. The temporary
reconcile branch was therefore rebuilt again from f7c261a7... rather than
stacking another merge on the stale base.

## Qualification on the current canonical base

Exact production postimage 8f3f2d487fe177b74a14e0c5aa2942d25c342e09:

Corrected-source workflow:
https://github.com/abhedwig-cell/SWAP5/actions/runs/36994347915

Result: SUCCESS.

It proves on the reconciled postimage:

- frozen corrected source replay at O0 and O2;
- positive source-backed IcTopMp > 1 covering transfer;
- serialized source transaction mass closure;
- discard/replay identity;
- commit publication;
- persistence/restart identity;
- A9 surface-connected top-input preservation;
- A10 rapid-drainage preservation;
- PERCH20 transaction-continuation preservation;
- PERCH20 restart-lifecycle preservation.

Canonical focused backend workflow:
https://github.com/abhedwig-cell/SWAP5/actions/runs/36994347868

Result: SUCCESS.

It proves the current A26 live-trial preparer and serialized backend compile/runtime
gate after the MIGMAC01 composition. The backend gate was updated only for the
new covering-layer module dependency introduced by this migration.

## G7

Exact B1.11 last-rate parity remains explicitly NOT PROVEN. The persisted
B1.11 last-rate artifact does not contain the complete mutable macropore carrier
at that rate evaluation, so the previous rate comparison is not state-identical.
The numerical discrepancy remains recorded as negative/non-parity evidence.
No tolerance was widened and no operator mismatch is claimed.

## Admission classification

Implemented: TRUE
Persisted: TRUE
Tested: TRUE
Qualified: TRUE
Preserved: TRUE
Production-admission candidate: TRUE
Canonical base reconciled: TRUE
Canonically admitted: FALSE
Closed: FALSE

No remaining scientific or numerical blocker is identified for this bounded
MIGMAC01 admission candidate. Canonical admission still requires the integration
PR/merge and post-merge authority update; this document does not claim either.
