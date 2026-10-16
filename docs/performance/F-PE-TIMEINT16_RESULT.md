# F-PE-TIMEINT16 result — moisture Thomas-Gladwell Richards integration

Date: 2026-09-29

Status:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

Canonical authority incorporated before result write:

`integration/f-ci-canonical@7d4aa0cb6790f293ff486f716c6c4eadd7d18eb8`

Final qualification authority:

- workflow run: `36525820591`;
- inverse job: `109268529143`, SUCCESS;
- provider-consistent-stage job: `109268529363`, SUCCESS;
- startup-attribution job: `109268529401`, SUCCESS;
- smooth-mechanism job: `109268529420`, SUCCESS.

## Result structure

TIMEINT16 contains three logically distinct experiments.

They must not be conflated.

### P0 — direct moisture-TG reconstruction with fully implicit HeadCalc endpoint

Frozen classification:

`CLOSED_TG_SECOND_ORDER_NOT_REPRODUCED`

All four smooth ladders completed.

Physical conservation and constitutive consistency passed, but temporal order did not:

- median refined top-head order: about `0.968`;
- 0/4 cases >= 1.5;
- physical interval ledgers at roundoff;
- constitutive roundtrip at roundoff;
- median work ratio versus fully implicit BE: about `1.0`.

This established that simply combining an accepted-origin physical derivative with the ordinary fully implicit SWAP endpoint solve is not a reproduced second-order Thomas-Gladwell mechanism.

### TIMEINT16B — event-local BE startup and collocation attribution

Frozen classification:

`TG_ORDER_REDUCTION_PERSISTS_AFTER_STARTUP`

Rannacher-style startup does not rescue the order.

Across all four ladders:

- median refined top-head order: about `1.0834`;
- median refined top-moisture order: about `1.0811`;
- 0/4 head orders >= 1.5;
- median work ratio versus fully implicit BE: about `1.075`;
- physical ledger: PASS;
- constitutive roundtrip: PASS;
- accepted-origin derivative collocation: PASS;
- predictor native balance residual: PASS.

Representative maximum diagnostics:

- accepted-origin mass-rate error: order `1e-15 cm/d`;
- predictor native balance residual: below `9e-13 cm/d`;
- physical interval ledger: order `1e-14 cm`.

Therefore:

- the order reduction is not a head-only postprocessing artifact;
- the moisture state itself is first-order on this composition;
- the t=0 forcing discontinuity is not the dominant cause;
- the origin and predictor balances are internally consistent.

### TIMEINT16C — provider-consistent Thomas-Gladwell coefficient staging

Frozen classification:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

This arm changes one architectural point only:

the hydraulic coefficients used for the TG endpoint equation are evaluated consistently from a current-step forward state predictor and then held fixed during the endpoint nonlinear storage/gradient solve.

It does not use previous-step K history.

It does not use dynamic top.

It does not change the physical interval mass contract.

It does not tune tolerances.

## TIMEINT16C accuracy result

All 4/4 ladders complete.

Refined top-head order:

- B01 / 2 cm d-1: `1.99544`;
- B01 / 4 cm d-1: `1.99114`;
- O05 / 2 cm d-1: `1.99965`;
- O05 / 4 cm d-1: `1.99972`.

Median refined top-head order:

`1.99755`

Refined top-moisture order:

- B01 / 2 cm d-1: `1.99544`;
- B01 / 4 cm d-1: `1.99114`;
- O05 / 2 cm d-1: `1.99965`;
- O05 / 4 cm d-1: `1.99971`.

Median refined top-moisture order:

`1.99755`

All 4/4 individual head ladders exceed the frozen 1.5 gate.

This is a clean reproduction of second-order asymptotic behavior on the smooth fixed-flux bank.

## TIMEINT16C conservation and state consistency

All frozen conservation/state gates pass.

Maximum observed physical per-step ledgers are order `1e-14 cm`.

Maximum cumulative ledgers are order `1e-14 cm`.

Maximum constitutive theta roundtrip error:

- B01: about `5.55e-17`;
- O05: about `1.39e-17`.

Independent inverse qualification passes:

- B01 maximum theta roundtrip about `5.55e-17`;
- O05 maximum theta roundtrip about `5.55e-17`.

The larger O05 head roundtrip magnitude, about `1.87e-8 cm`, is not the preregistered physical gate. The actual theta -> head -> theta error is roundoff scale.

## TIMEINT16C coefficient-stage evidence

The predicted coefficient stage is nontrivial.

Maximum absolute differences between predicted-stage K and accepted-origin K include:

- B01 / 2 cm d-1: about `8.57e-3`;
- B01 / 4 cm d-1: about `2.09e-2`;
- O05 / 2 cm d-1: about `2.24e-3`;
- O05 / 4 cm d-1: about `6.08e-3`.

Thus the positive order result is not produced by a degenerate predictor that simply reproduces origin K.

Predicted K remains finite and positive throughout the frozen bank.

## TIMEINT16C endpoint balance

Maximum native endpoint balance-rate residuals are below about `9e-13 cm/d`, far below the frozen `5e-8 cm/d` gate.

The endpoint solve therefore remains numerically balanced while using provider-consistent fixed predicted conductivity.

## Work result

Median deterministic work ratio versus KLAG Backward Euler:

`1.0`

This passes the frozen `<= 1.15` gate with substantial margin.

The mechanism therefore achieves:

- second-order temporal convergence;
- exact physical interval conservation;
- constitutive endpoint consistency;
- provider-consistent hydraulic coefficient staging;
- essentially no deterministic per-step work penalty relative to KLAG BE on this bank.

## Mechanism attribution

The sequence P0 -> B -> C identifies the defect narrowly.

The negative P0/B results are not evidence that Thomas-Gladwell is unsuitable for Richards.

They show that the earlier SWAP composition mixed a TG moisture update with an endpoint hydraulic operator whose coefficient evaluation did not satisfy the stage-consistency requirements needed by the second-order truncation argument.

TIMEINT16C removes that inconsistency by:

1. evaluating the accepted-origin physical derivative;
2. predicting the current-step moisture endpoint from that derivative;
3. projecting the predictor through the exact benchmark retention relation;
4. evaluating K from the same constitutive provider on that predicted state;
5. holding that K fixed during the endpoint solve;
6. applying the TG moisture average;
7. projecting the accepted TG moisture state back to a constitutively consistent head.

That composition recovers nearly ideal order 2 in both moisture and head.

## What is not yet qualified

This result does not yet qualify:

- production source changes;
- dynamic-top boundary transitions;
- ponding;
- variable-step Thomas-Gladwell;
- LTE-based timestep control;
- hard-event restart semantics outside this fixed-flux smooth bank;
- macropore coupling;
- root-water uptake time variation;
- groundwater-coupled boundary variation;
- previous-step K extrapolation;
- production default replacement.

## Production boundary

No production `src/**` change is admitted by TIMEINT16.

No mass-balance tolerance change.

No transaction mass-contract change.

`LEGACY_NUMERICS` remains the production default.
