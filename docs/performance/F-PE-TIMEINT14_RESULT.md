# F-PE-TIMEINT14 result — conservative multistep storage attribution

Date: 2026-09-29

Status: `BDF2_ALGORITHMIC_CONSERVATION_CONFIRMED_PHYSICAL_INTERVAL_CONTRACT_INCOMPATIBLE`

Authority:

- canonical base: `integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`;
- Actions run: `36519039612`;
- attribution job: `109247667772`;
- conclusion: SUCCESS.

## Attribution bank

The TIMEINT13 extrapolated-K BDF2 dynamic-top candidate was rerun without changing any solver, forcing, conductivity, boundary or timestep semantics.

Ten trajectories complete, identical to the TIMEINT13 completed domain.

The two pre-existing incomplete cases remain:

- O05/POND;
- O14/POND.

## BDF2 identity

For constant-step soil storage:

`1.5 S[n+1] - 2 S[n] + 0.5 S[n-1] = h F[n+1]`.

Therefore the ordinary physical one-step ledger:

`L = (S[n+1]-S[n]) - h F[n+1]`

must equal:

`R_hist = -0.5 (S[n+1]-2S[n]+S[n-1])`.

This prediction is confirmed.

Maximum over all completed BDF2 steps:

- `|L - R_hist| = 7.52e-14 cm`.

The TIMEINT13 O(1e-3..1e-2 cm) apparent ledger mismatch is therefore not unexplained mass loss.

## Algorithmic storage

Define:

`A[n] = 1.5 S[n] - 0.5 S[n-1] + P[n]`

with ponding storage `P`.

Then the external dynamic-top balance satisfies:

`A[n+1]-A[n] = rain*h - runoff - bottom_outward_exchange`.

Observed maximum algorithmic interval ledger:

`8.23e-14 cm`.

This is roundoff scale.

The first BE bootstrap step retains the ordinary physical ledger.

Maximum bootstrap physical ledger:

`4.49e-14 cm`.

## Interpretation

The TIMEINT13 multistep formulation is discretely conservative.

The conflict is semantic:

- SWAP5 transaction mass authority currently defines accepted interval conservation using physical endpoint storage difference;
- BDF2 naturally conserves a history-dependent algorithmic storage.

For a step with nonzero history curvature, both identities cannot be exact simultaneously while keeping the same endpoint and the same currently published external step fluxes.

## Important consequence

The TIMEINT13 blocker is not fixed by loosening water-balance tolerances.

It requires an explicit integrator-aware mass/flux design.

Possible architectural solutions include:

1. publish a qualified numerical-history storage/debt contribution in the transaction mass contract;
2. reconstruct external integrated fluxes using a BDF2-consistent quadrature/history rule;
3. use a second-order one-step conservative integrator whose natural storage increment is the physical accepted-state difference.

TIMEINT14 does not select among these options yet.

## Decision

Classification:

`BDF2_ALGORITHMIC_CONSERVATION_CONFIRMED_PHYSICAL_INTERVAL_CONTRACT_INCOMPATIBLE`.

No production source change.
