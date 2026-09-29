# F-PE-TIMEINT15 P0 result — conservative trapezoidal one-step mechanism

Date: 2026-09-29

Status: `CLOSED_P0_TRAPEZOIDAL_ORDER_REDUCED`

Authority:

- canonical base: `integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`;
- Actions run: `36519981774`;
- smooth-mechanism job: `109250500818`;
- conclusion: SUCCESS.

## P0 outcome

The physical accepted-interval mass objective is achieved.

Across every completed trapezoidal run:

- ordinary physical per-step ledgers remain at roundoff scale;
- cumulative physical ledgers remain at roundoff scale;
- no BDF2-style numerical history term is required.

Thus the one-step storage/flux formulation is compatible with the existing physical transaction mass identity.

However the frozen temporal-order gates fail.

### TR_KIMPL

- only 3/4 complete ladders;
- B01 / 2 cm/day / dt=0.00125 d fails at step 25 under MAXIT=8;
- refined top-head orders on complete ladders:
  - B01 / 4 cm/day: about 0.976;
  - O05 / 2 cm/day: about 0.968;
  - O05 / 4 cm/day: about 0.966;
- median refined order: about 0.968;
- physical ledger gate: PASS;
- median work ratio versus fully implicit BE: about 1.0.

### TR_KPRED

- 4/4 ladders complete;
- zero conductivity clamps;
- refined top-head orders:
  - B01 / 2 cm/day: about 0.645;
  - B01 / 4 cm/day: about 0.641;
  - O05 / 2 cm/day: about 0.619;
  - O05 / 4 cm/day: about 0.563;
- median refined order: about 0.630;
- physical ledger gate: PASS;
- median work ratio versus KLAG BE: about 1.0.

Classification under the frozen P0 rules:

`CLOSED_CONSERVATIVE_TRAPEZOIDAL_NOT_QUALIFIED`.

## Attribution observations

Two distinct mechanisms require separation before abandoning the one-step family.

### 1. TR_KIMPL order reduction

The nominally smooth hydraulic bank starts from uniform equilibrium head and applies the nonzero infiltration rate abruptly at t=0.

This is a temporal boundary/initial compatibility discontinuity.

Crank-Nicolson/trapezoidal integration is not L-stable and is known to suffer startup/order reduction for parabolic problems with nonsmooth initial/boundary data.

The nearly identical O(1) refined orders across three independent ladders are consistent with this mechanism.

This attribution is not yet proven.

### 2. TR_KPRED test-only origin-operator inconsistency

The TIMEINT13 predicted-K provider returns the same predicted endpoint conductivity vector for all constitutive conductivity demands within a solve.

In the P0 materialization, the trapezoidal origin operator G_n was therefore captured using predicted K_(n+1), not exact accepted K_n.

That arm is not a mathematically faithful trapezoidal average of exact-origin and predicted-endpoint operators.

Its low order cannot be used to reject second-order predicted-conductivity trapezoidal integration.

## Decision

P0 qualification remains negative.

No P0 gate is relaxed.

Open TIMEINT15A only to test the preregistered startup/order-reduction attribution for TR_KIMPL.

A corrected predicted-K trapezoidal arm is not opened unless the underlying trapezoidal mechanism first recovers second-order behavior.
