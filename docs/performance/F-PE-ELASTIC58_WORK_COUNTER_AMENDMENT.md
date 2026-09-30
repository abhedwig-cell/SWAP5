# F-PE-ELASTIC58 — work-counter semantics amendment

Date: 2026-09-30

Status: HARNESS_SEMANTICS_CORRECTION_BEFORE_QUALIFIED_RESULT

Parent:
`F-PE-ELASTIC58_TRANSACTION_COST_PREREGISTRATION.md`

## Reason

The preregistration listed direct-solver HeadCalc calls as one physical work
counter.

The typed `soil_water_solver_diagnostics_t` contract does not publish a
HeadCalc-call counter. It publishes:
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- alternative solver calls;
- constitutive evaluation counters;
- workspace reset counters.

HeadCalc calls are available at higher serialized transaction observation
layers, but not from the direct-solve result used by the frozen ELASTIC55/57
physical replay.

## Correction

Part B shall characterize:
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- certificate additional tridiagonal solves.

It shall not invent or infer HeadCalc calls.

Part A remains unchanged and already verifies that the transaction result can
carry HeadCalc accounting when the model supplies it.

No physical/numerical case, budget, alpha, controller decision or production
source changes.
