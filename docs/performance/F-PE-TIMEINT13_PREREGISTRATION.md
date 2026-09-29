# F-PE-TIMEINT13 preregistration — extrapolated-coefficient semi-implicit BDF2

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@199566655db5b13483194e16bb81a154f6fc2547`

Parent evidence:

- TIMEINT04-05: fully implicit BDF2 is second-order on smooth fixed-flux trajectories and supports accepted step ratios 0.5..2.0;
- TIMEINT12A: fully implicit dynamic-top BE is too nonlinear-costly/nonuniform for direct BDF2 extension;
- KIMPL-DYNTOP01-02: most failures recover with more Newton iterations, but O14/MOIST needs MAXIT=24.

## Purpose

Test whether a second-order semi-implicit coefficient treatment can retain BDF2 temporal order without endpoint-fully-implicit conductivity.

No production source change.

## Candidate method

Storage derivative:

variable-step BDF2, using the already qualified TIMEINT05 coefficients.

For current requested step `h_n` and previous accepted step `h_{n-1}`, define ratio:

`r = h_n / h_{n-1}`.

For each node, predict the new endpoint pressure head from the two accepted states:

`h_pred = (1+r) h^n - r h^{n-1}`.

Evaluate hydraulic conductivity once at `h_pred`:

`K_pred = K(h_pred)`.

During the nonlinear solve:

- water content and capacity remain evaluated at the Newton candidate;
- conductivity is frozen to `K_pred`;
- face conductivity uses the existing method-1 arithmetic mean;
- no `dK/dh` Jacobian contribution is used.

This is a second-order explicit extrapolation of the coefficient on smooth histories while preserving positive constitutive K through evaluation of the retention/conductivity law at predicted head.

Bootstrap:

- first accepted step uses ordinary first-order BE with current-state lagged K;
- BDF2/extrapolated K starts only when two accepted states exist.

## P0 — smooth fixed-flux order qualification

Use the same smooth fixed-flux envelope used for TIMEINT04-05.

Materials:

- B01;
- O05.

Rain forcing:

- 1.0 cm/day;
- 4.0 cm/day.

Fixed-step convergence ladder:

- dt = 0.005;
- 0.0025;
- 0.00125;
- 0.000625 d.

Horizon:

0.04 d.

Compare:

1. `BE_KLAG`: existing first-order baseline;
2. `BDF2_KPRED`: BDF2 storage + extrapolated-head K predictor.

Primary order metric:

refined top-head order from the three finest levels.

Frozen P0 gates:

1. all 8 BDF2_KPRED trajectories complete;
2. every state finite;
3. median refined top-head order >=1.70;
4. at least 3/4 material/forcing cases have refined order >=1.50;
5. no case refined order <1.25;
6. deterministic work per accepted step <=1.15 times BE_KLAG median;
7. no alternative-solver pathology.

If P0 fails, close TIMEINT13.

## P1 — dynamic-top mechanism gate

Only if P0 passes.

Preregister separately before exposure.

P1 may apply the same predicted-K operator to corrected dynamic-top, with first-order history invalidation/fallback at detected boundary-regime transitions.

No wet/ponding dynamic-top result is exposed in P0.

## Production boundary

Research only.
