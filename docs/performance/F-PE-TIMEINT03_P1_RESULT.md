# F-PE-TIMEINT03 P1 result — fully implicit BDF2

Date: 2026-09-28

Status: `SECOND_ORDER_SIGNAL_WITH_ONE_NONLINEAR_COMPLETION_FAILURE`

Authority:

- Actions run: `36442793708`;
- implicit-bdf2 job: `108997311764`;
- conclusion: SUCCESS.

## Result

BDF2_KIMPL:

- full ladders complete: 3/4;
- median refined top-head order over complete cases: about 2.055;
- complete-case individual orders:
  - B01, 2 cm/day: 2.049;
  - O05, 2 cm/day: 2.073;
  - O05, 4 cm/day: 2.055;
- median work per step: 16.125;
- BE_KIMPL median work per step: 16.1875;
- work ratio: about 0.996.

The sole incomplete ladder is:

- B01;
- infiltration 4 cm/day;
- dt=0.00125 d;
- failure at step 25;
- MAXIT=8;
- diagnostics at failure: NL=8, BACK=8, JAC=8, LIN=8.

## Interpretation

Where the fully implicit BDF2 route completes, it displays the expected second-order convergence and no material per-step work penalty relative to fully implicit Backward Euler.

P1 does not advance because the frozen gate required 4/4 complete ladders.

The failure is suitable for a separately preregistered nonlinear-effort attribution because it occurs exactly at the iteration cap.

## Decision

P1 status remains not qualified.

Open TIMEINT03A to test uniform MAXIT sensitivity over the whole BDF2_KIMPL matrix.
