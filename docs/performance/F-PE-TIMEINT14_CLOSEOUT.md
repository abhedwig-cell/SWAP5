# F-PE-TIMEINT14 closeout — multistep conservation and transaction mass semantics

Date: 2026-09-29

Final status:

`CLOSED_CONSERVATION_ATTRIBUTED_CONTRACT_REDESIGN_REQUIRED`

## What is established

TIMEINT14 proves that the large TIMEINT13 dynamic-top physical-ledger residual is exactly the algebraic BDF2 history-storage term.

The mismatch is reproduced to roundoff:

- max representation mismatch ~7.5e-14 cm;
- max algorithmic-storage ledger ~8.2e-14 cm;
- BE bootstrap ledger ~4.5e-14 cm.

Thus extrapolated-K BDF2 is not losing water inside its discrete conservation equation.

## Why production is still blocked

SWAP5 transaction semantics intentionally use physical endpoint storage:

`storage_end - storage_start = integrated_in - integrated_out`.

Constant-step BDF2 instead exactly conserves:

`A[n] = 1.5 S[n] - 0.5 S[n-1] + P[n]`.

That algorithmic storage contains numerical history.

Replacing physical storage with `A` silently would weaken the meaning of the transaction mass contract and is not authorized.

## Recommended successor

`F-PE-TIMEINT15 — integrator-consistent physical flux reconstruction and conservative publication`.

TIMEINT15 should test whether physical interval fluxes can be reconstructed consistently with BDF2 while preserving:

- physical endpoint storage identity;
- component-wise external flux meaning;
- second-order temporal accuracy;
- exact transaction publication;
- history/restart semantics.

For constant-step BDF2, the exact storage recurrence is:

`Delta S[n] = (2/3) h F[n+1] + (1/3) Delta S[n-1]`.

For variable-step BDF2 with coefficients `a0,a1,a2`:

`Delta S[n] = (h/a0) F[n+1] + (a2/a0) Delta S[n-1]`.

This suggests an integrator-consistent recursive flux quadrature, but component-wise physical interpretation and dynamic-top surface storage must be qualified rather than assumed.

If a clean physical flux reconstruction cannot be justified, the next alternative should be a conservative second-order one-step method rather than changing the mass contract.

## Separate robustness boundary

O05/POND remains a common-domain solver failure in this harness.

O14/POND remains an extrapolated-K-specific robustness failure at step 2.

Those issues are independent from the conservation attribution and remain open for any later dynamic-top admission.

## Production boundary

No production `src/**` changes.

LEGACY_NUMERICS remains production default.
