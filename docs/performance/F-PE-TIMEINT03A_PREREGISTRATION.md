# F-PE-TIMEINT03A preregistration — BDF2 nonlinear-robustness attribution

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent:

F-PE-TIMEINT03 P1.

Observed P1 result before this workunit:

- BDF2_KIMPL completes 3/4 smooth cases over the full dt ladder;
- the three complete cases have refined top-head order approximately 2.05;
- median work per step is approximately equal to fully implicit BE;
- only B01 with infiltration 4 cm/day at dt=0.00125 d fails;
- failure occurs at step 25/32 with retry advised after exactly 8 nonlinear iterations.

P1 remains failed because its frozen 4/4 completion gate was not met.

## Question

Is the isolated BDF2_KIMPL failure primarily caused by the frozen MAXIT=8 nonlinear iteration cap?

## Frozen attribution

Use only:

- material B01;
- initial h=-100 cm;
- fixed top infiltration 4 cm/day;
- prescribed zero bottom flux;
- dt=0.00125 d;
- fully implicit conductivity;
- BDF2 storage after the same BE bootstrap;
- all P1 tolerances unchanged.

MAXIT arms:

- 8;
- 12;
- 16;
- 24.

Max backtracking remains 8.

Record:

- completion;
- first failed step;
- nonlinear iterations;
- backtracks/Jacobians/linear solves;
- final endpoint when complete;
- total deterministic work.

## Interpretation rules

- If MAXIT 12 or 16 restores completion with no other change, classify the P1 miss as `NONLINEAR_ITERATION_CAP_SENSITIVITY`.
- If only MAXIT 24 restores completion, classify as `MATERIAL_NONLINEAR_EFFORT`, not yet suitable for production BDF2.
- If no arm completes, classify as `BDF2_NONLINEAR_PATHOLOGY`.

No TIMEINT03 P1 gate is changed after exposure.

A separate successor may study a BDF2-specific nonlinear initial predictor only if this attribution shows that iteration capacity is the limiting mechanism.
