# F-PE-TIMEINT14A result — BDF2 interval-mass identity

Date: 2026-09-29

Status: `BDF2_HISTORY_CONTRACT_MISMATCH_CONFIRMED`

Canonical base:

`integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`

Primary Actions authority:

- run: `36519088560`;
- interval-identity job: `109247811367`;
- conclusion: SUCCESS.

## Frozen identity

For the constant-step BDF2 soil-storage operator:

`1.5 S_(n+1) - 2 S_n + 0.5 S_(n-1) = h F_(n+1)`

the ordinary one-step physical ledger was predicted to satisfy:

`Rphysical = Rhistory + O(solver/balance tolerance)`

with:

`Rhistory = -0.5 (S_(n+1) - 2 S_n + S_(n-1))`.

The BE bootstrap has no history correction and must retain the ordinary physical ledger.

## Result

Across the preregistered dynamic-top bank:

- accepted steps recorded: 241;
- BDF2 steps: 230;
- complete full trajectories: 10/12;
- BE bootstrap maximum absolute ledger: about `4.49e-14 cm`;
- maximum absolute `Rphysical-Rhistory`: about `7.51e-14 cm`;
- median absolute identity residual: about `9.16e-15 cm`;
- maximum ordinary physical ledger magnitude: about `3.77e-2 cm`;
- BDF2 steps with ordinary |ledger| >= 1e-3 cm: 38.

All frozen gates pass.

## Interpretation

The O(1e-3..1e-2 cm) ordinary interval residual observed in TIMEINT13 is not an unexplained water leak.

It is the exact algebraic history term implied by combining:

- a BDF2 soil-water storage derivative; and
- a one-step physical interval mass identity based on consecutive accepted states.

The mismatch remains large enough that it cannot be hidden by numerical tolerance.

## Algorithmic storage

The equivalent telescoping multistep storage quantity:

`A_n = 1.5 S_n - 0.5 S_(n-1) + P_n`

closes against the unchanged external interval mass to roundoff on the completed trajectories.

This confirms algorithmic conservation of the tested method.

However, `A_n` is not the physical water storage at time n.

It must therefore not silently replace physical storage in SWAP5 transaction publication.

## Decision

Classification:

`BDF2_HISTORY_CONTRACT_MISMATCH_CONFIRMED`

No production mass semantics change.

Open a successor that restores the existing physical interval identity by changing the temporal formulation/accounting consistently rather than relabelling history debt as physical mass.
