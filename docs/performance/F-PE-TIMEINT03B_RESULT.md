# F-PE-TIMEINT03B result — BDF2 Newton predictor attribution

Date: 2026-09-28

Status: `LINEAR_EXTRAPOLATION_PREDICTOR_REJECTED`

Authority:

- Actions run: `36443742413`;
- predictor-attribution job: `109000563517`;
- conclusion: SUCCESS.

## Frozen comparison

BDF2_KIMPL, MAXIT=8.

Compared:

- BASE_GUESS: current h^n Newton initial guess;
- LINEAR_EXTRAP: h_guess = 2 h^n - h^{n-1} after bootstrap.

The physical base state, BDF2 storage history, operator and tolerances were unchanged.

## Result

BASE_GUESS:

- complete ladders: 3/4;
- median refined top-head order: about 2.055;
- B01 4 cm/day fails at dt=0.00125 d, step 25.

LINEAR_EXTRAP:

- complete ladders: 2/4;
- median refined top-head order on complete cases: about 2.064;
- both B01 cases fail at dt=0.00125 d, step 7;
- O05 retains second-order behavior.

Median work per step of LINEAR_EXTRAP:

- about 17.17;
- about 1.061 times BE_KIMPL.

On common complete cases the predictor is not more expensive overall, but it reduces nonlinear robustness for B01.

## Decision

The simple linear BDF2 predictor does not restore the missing convergence basin.

Classification:

`BDF2_INITIAL_GUESS_RESCUE_REJECTED`

Per preregistration, no further predictor rescue is introduced in TIMEINT03.
