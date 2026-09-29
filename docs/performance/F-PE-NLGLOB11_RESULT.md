# F-PE-NLGLOB11 result — TG saturated coefficient-stage predictor

Date: 2026-09-29

Status:

`CLOSED_TG_SAT_EXTENSION_PHYSICAL_ADMISSIBILITY_FAILED`

Canonical base:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Qualification authority:

- workflow run: `36551065621`;
- job: `109349078694`;
- conclusion: SUCCESS.

## Frozen question

Can the TG current-step coefficient-stage predictor use an explicit saturated constitutive extension above `theta_s` without changing the accepted moisture state, while retaining TIMEINT16C second-order accuracy and physical admissibility?

## Smooth TIMEINT16C result

The smooth fixed-flux qualification remains fully positive.

The modified predictor reproduces the existing TIMEINT16C result:

- 4/4 ladders complete;
- median refined top-head order: about `1.99755`;
- median refined top-theta order: about `1.99755`;
- all 4/4 individual head orders >=1.5;
- physical and cumulative ledgers at roundoff;
- median work ratio versus KLAG BE: `1.0`.

Thus the saturated coefficient-stage extension does not damage the smooth second-order mechanism where the extension is inactive.

## Dynamic-top result

The original 7 `PREDICTED_RETENTION_DOMAIN_FAILED` stops disappear.

However, those same O05 HEAD/RUNOFF TG trajectories then continue until the final accepted TG moisture projection fails the exact retention roundtrip:

`F_PE_TIMEINT17A_FAIL TG retention roundtrip failed`.

The seven affected cases remain:

- O05;
- TG only;
- HEAD and RUNOFF;
- the same dt ladder identified by NLGLOB10.

The process failure is therefore not a numerical implementation artifact. It is the accepted TG state itself leaving the physical retention domain after the auxiliary predictor-domain restriction is removed.

## Frozen classification

`CLOSED_TG_SAT_EXTENSION_PHYSICAL_ADMISSIBILITY_FAILED`.

The candidate fails the accepted-state physical-admissibility gate.

No accepted-state clipping or projection is authorized.

## Interpretation

NLGLOB10 correctly identified the first visible failure as an auxiliary forward-predictor overshoot.

NLGLOB11 shows that this overshoot was also an early warning of a stronger issue:

for these near-saturated dynamic-top trajectories, the unchanged full-step TG moisture update can itself overshoot saturation.

Therefore a pure coefficient-stage saturation extension cannot solve the TG near-saturation problem.

The smooth TIMEINT16C second-order authority remains valid.

## Consequence

Any successor must modify the temporal construction before acceptance, not merely the temporary K-stage representation.

A bounded candidate may investigate a current-step substage or event-local temporal split that keeps both predictor and accepted TG moisture in-domain while preserving:

- the exact physical mass contract;
- current-step/provider-consistent K staging;
- second-order smooth behavior;
- no accepted-state clipping.

## Production boundary

Research only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep-controller or route/event default change.

`LEGACY_NUMERICS` remains production default.
