# F-PE-TIMEINT03B preregistration — BDF2 Newton predictor attribution

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0d131bfc0d7b490b936b4315b17d175342e29ee6`

Parent evidence:

- TIMEINT03 P1 shows second-order BDF2_KIMPL behavior in all complete ladders;
- TIMEINT03A shows the sole incomplete case fails at the same physical step for MAXIT 8, 12, 16 and 24.

## Hypothesis

The explicit state binding initializes every nonlinear solve from the accepted endpoint `h^n`.

For constant-step BDF2 a natural second-order-consistent predictor is:

`h_predict = 2 h^n - h^{n-1}`.

The physical BDF2 origin remains `h^n`; the predictor is only a Newton initial guess.

## Test-only implementation boundary

Materialize the TIMEINT03 explicit binding test-only.

Add an optional predictor input that, after normal state-binding initialization:

- replaces only the candidate Newton head vector `state_binding%h`;
- leaves `hm1/thetm1`, physical base state, forcing, BDF2 storage history and transaction origin unchanged.

The predictor water content must be recomputed consistently from the constitutive provider before HeadCalc evaluates the initial residual, or the test-only binding must otherwise guarantee the initial candidate tuple is self-consistent.

No production source change.

## Arms

For the complete four-case BDF2_KIMPL dt ladder compare:

A. `BASE_GUESS`
- current initial guess h^n.

B. `LINEAR_EXTRAP`
- after the BE bootstrap and whenever two accepted head states exist:
  `h_guess = 2 h^n - h^{n-1}`;
- bootstrap step retains h^n.

MAXIT returns to 8.

All other numerical controls remain P1.

## Advancement gate

LINEAR_EXTRAP advances only if:

1. 4/4 full ladders complete;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined orders >=1.5;
4. no finite-state/mass failure;
5. median deterministic work per step <=1.5 times BE_KIMPL;
6. median work per step is not worse than BASE_GUESS by more than 10% on cases where both complete.

If the predictor restores completion while preserving second order, classify the failure as `BDF2_INITIAL_GUESS_PATHOLOGY`.

If it does not, close TIMEINT03 without further predictor rescue in this workunit.

Dynamic-top and variable-step BDF2 remain out of scope.
