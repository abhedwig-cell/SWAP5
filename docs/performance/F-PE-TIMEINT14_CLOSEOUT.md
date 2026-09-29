# F-PE-TIMEINT14 closeout — conservative BDF2 and physical interval mass contract

Date: 2026-09-29

Final status:

`CLOSED_BDF2_INCOMPATIBLE_WITH_INTERVAL_MASS_CONTRACT`

Canonical authority incorporated before closeout:

`integration/f-ci-canonical@295a13b83ac44efa7b2ff0e0d2fb7c86e6b31e70`

That canonical commit is the merge of PR #746 and has the same TIMEINT14 tree that passed the qualification run.

Branch-head requalification:

- Actions run: `36519269141`;
- `interval-identity`: SUCCESS;
- `attribution`: SUCCESS.

No production `src/**` change is part of TIMEINT14.

## What TIMEINT14 establishes

The large ordinary physical-ledger residual observed in TIMEINT13 is exactly the algebraic BDF2 history-storage term, not an unexplained water leak.

For constant-step soil storage,

`1.5 S[n+1] - 2 S[n] + 0.5 S[n-1] = h F[n+1]`.

With physical interval storage increment

`DeltaS[n] = S[n+1]-S[n]`,

the ordinary one-step ledger against the BDF2 endpoint flux mass is

`L[n] = DeltaS[n] - h F[n+1]`

and therefore exactly

`L[n] = -0.5 (S[n+1]-2S[n]+S[n-1])`.

The preregistered dynamic-top bank confirms this identity to roundoff:

- accepted steps recorded: 241;
- BDF2 steps: 230;
- complete trajectories: 10/12;
- max `|physical_ledger-history_term|`: about `7.5e-14 cm`;
- median identity residual: about `9.2e-15 cm`;
- max algorithmic-storage ledger: about `8.2e-14 cm`;
- max BE-bootstrap physical ledger: about `4.5e-14 cm`;
- max ordinary physical ledger: about `3.77e-2 cm`;
- 38 BDF2 steps have ordinary `|ledger| >= 1e-3 cm`.

The signal is therefore structural and cannot be removed by tolerance adjustment.

## Temporal residual versus physical ledger

TIMEINT14 keeps two objects explicitly separate.

### A. temporal-discretization residual

BDF2 conserves the history-dependent algorithmic storage

`A[n] = 1.5 S[n] - 0.5 S[n-1] + P[n]`

against the external discrete flux mass.

This identity closes to roundoff on the qualification bank.

### B. physical accepted-interval mass ledger

SWAP5 transaction authority requires

`(S[n+1]+P[n+1])-(S[n]+P[n]) = integrated_in[n]-integrated_out[n]`

for the accepted interval itself.

For nonzero BDF2 history curvature, this identity and the unchanged BDF2 endpoint equation cannot both be exact with the same external interval mass.

Algorithmic conservation therefore does not satisfy the existing physical transaction contract.

## Candidate assessment

The preregistered candidate set closes as follows.

### A. conservative increment-form BDF2

BDF2 can be rearranged exactly as

`DeltaS[n] = (2/3) h F[n+1] + (1/3) DeltaS[n-1]`.

This is mathematically exact and keeps second-order BDF2 endpoint behavior.

It does not preserve the existing interval lineage: one third of the previous accepted interval storage increment is required in the current interval identity.

If that history term is published as current inflow/outflow, physical mass is reassigned between transactions.

Decision: rejected under the existing physical interval contract.

### B. unchanged BDF2 endpoint plus reconstructed physical interval flux

One can force exact closure by defining

`Qphys[n] = DeltaS[n]`

or equivalently by adding the BDF2 history correction to `h F[n+1]`.

That is a storage-derived correction, not an independently evaluated current-interval physical flux integral.

It makes the ledger tautological and destroys the independent meaning of external mass publication.

Decision: rejected as physical transaction accounting.

### C. second-order physical flux/source quadrature

A genuine current-interval second-order quadrature would need to be built only from physical boundary/source rates belonging to `[t_n,t_(n+1)]` while also matching the unchanged BDF2 endpoint exactly.

The BDF2 identity shows that the exact current storage increment depends on the previous increment whenever history curvature is nonzero.

Therefore no purely current-interval quadrature can make the unchanged BDF2 endpoint satisfy the existing exact interval identity for the general case without importing history or changing the temporal equation.

Decision: no admissible unchanged-BDF2 solution under the current contract.

### D. explicit numerical history debt

The history difference may be stored transparently as a numerical state

`H[n] = A[n]-(S[n]+P[n])`.

Then

`physical_increment + DeltaH = external_discrete_mass`.

This is a valid numerical accounting identity and would support rollback/checkpoint semantics if explicitly carried as integrator history.

But `DeltaH` is not water. Adding it to the physical ledger would change the transaction mass contract.

Decision: valid diagnostic/integrator state, rejected as a way to claim the current physical interval ledger is satisfied.

## Cumulative conservation

The ordinary physical BDF2 ledger does not become exactly conservative merely by summing many intervals.

For constant-step BDF2 the history residuals telescope to an endpoint-increment remainder, approximately

`sum L[n] = -0.5 (DeltaS[last]-DeltaS[first-BDF2-reference])`.

For smooth solutions that remainder shrinks with timestep, but it is not identically zero and therefore does not restore the current exact cumulative physical-mass meaning.

Algorithmic storage does telescope exactly. Physical storage does not under the unchanged BDF2 residual.

## Variable-step consequence

TIMEINT05's variable-step authority `0.5 <= r <= 2.0` remains valid as temporal-discretization research authority, but TIMEINT14 does not advance to variable-step conservative qualification.

For generic BDF2 coefficients `a0,a1,a2`,

`a0 S[n+1] + a1 S[n] + a2 S[n-1] = h F[n+1]`

can be rewritten as a recurrence for the physical increment that necessarily carries accepted history whenever `a2 != 0`.

Changing the adjacent step ratio changes the history weight, but does not remove the semantic conflict.

Therefore P3 is stopped by the constant-step contract result rather than by lack of variable-step testing.

## Transaction semantics consequence

Under the existing SWAP5 contract:

- rejected trials may roll back numerical history;
- accepted history may update only after commit;
- checkpoint/restore can carry BDF2 state cleanly;
- accepted endpoint lineage can remain transaction-safe.

Those properties are implementable.

The blocker is narrower and more fundamental: the external physical mass published for one accepted interval cannot equal the consecutive physical storage change for unchanged BDF2 without either:

1. reassigning history mass between intervals;
2. publishing a nonphysical history-debt term as if it were water;
3. making the external flux ledger storage-derived;
4. or changing the temporal formulation.

Therefore transaction safety alone does not rescue the physical mass contract.

## Dynamic-top consequence

No further dynamic-top BDF2 tuning is justified inside TIMEINT14.

The two existing robustness boundaries remain:

- O05/POND: common-domain solver failure;
- O14/POND: extrapolated-K-specific failure at step 2.

They are independent of the conservation attribution.

Even if both were solved, unchanged BDF2 would still fail the existing physical interval mass contract.

## Architecture decision

TIMEINT14 closes negative for BDF2 under the current transaction semantics.

This does **not** mean BDF2 is nonconservative numerically. It means:

- BDF2 is algorithmically conservative in a history-dependent storage variable;
- BDF2 is fundamentally incompatible with the **existing exact consecutive-state per-interval physical mass contract** if external interval fluxes retain their present physical meaning;
- changing the mass contract remains possible only as a separate architecture decision, not as a hidden TIMEINT14 fix.

The preferred next research direction is therefore a conservative second-order one-step temporal formulation whose natural balance is

`physical_storage_end - physical_storage_start = physical_interval_flux_integral`.

A trapezoidal/Crank-Nicolson-family route with predicted conductivity is now relevant again because it may preserve the favorable weak endpoint-conductivity coupling while restoring a one-step physical storage identity. It must be separately preregistered and qualified; TIMEINT14 makes no positive claim for it.

An alternative successor may investigate an explicitly redesigned integrator-aware mass contract, but that would be a deliberate change in SWAP5 transaction semantics and should not be conflated with conserving physical water under the current contract.

## Production boundary

`LEGACY_NUMERICS` remains production default.

No mass-balance tolerance was widened.

No history term was published as physical water.

No production BDF2 admission follows from TIMEINT14.
