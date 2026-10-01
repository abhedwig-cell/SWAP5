# F-PE-MIQUAL13 execution correction — first scaling run

Date: 2026-10-01

Status: `EXECUTION_INVALID_BEFORE_TIMING_EXPOSURE`

Workflow run `36828992205` reached the first frozen dimension (n=8) and stopped during untimed warmup because the direct reference solve did not converge under the frozen benchmark state.

No timed scaling sample was exposed.

The preregistration already defines `MIQUAL13_SOLVER_BEHAVIOR_NOT_COMPARABLE` for dimension-dependent convergence/iteration behavior.

Correction boundary:

- do not change dimensions, physics, tolerances, state or forcing;
- make the harness report a non-convergent frozen dimension as a structured invalid-dimension sample instead of terminating the entire run;
- continue the remaining frozen dimensions so n=13 versus n=16 can still be observed;
- classify the aggregate as `MIQUAL13_SOLVER_BEHAVIOR_NOT_COMPARABLE` if any frozen dimension is non-convergent.

The first run is execution-invalid and is not qualification authority.
