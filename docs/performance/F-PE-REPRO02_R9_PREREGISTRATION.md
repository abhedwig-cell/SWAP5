# F-PE-REPRO02 R9 — serialized physical advance versus canonical transaction

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1-R8 have excluded the direct physical request, solver effort controls, optional direction processing, inactive boundary carriers, minimum-step policy, isolated legacy-context binding and simple predictor process history.

The unresolved divergence is now between a direct serialized physical solve and the normal canonical transaction execution path.

## Question

For the same difficult-origin mode-5 forcing, does the serialized Reference backend succeed when asked for one physical reference-floor advance but fail when the same backend is executed through normal canonical whole-window transaction/retry orchestration?

## Cases

Six difficult PROFILE06 origins:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid.

Offsets:

- -0.001 cm;
- 0;
- +0.001 cm.

Use the R3-qualified generous physical controls:

- max nonlinear iterations = 48;
- max backtracking = 16;
- minimum step duration = 1e-10 day;
- existing 1e-12 balance/head tolerances.

Fresh process per point/arm.

## Arms

### FLOOR

Use the serialized Reference backend's admitted reference-floor sampling route for one full 1e-4 day physical advance from the same committed origin and prescribed-head forcing.

This arm must use the same physical parameters, state, forcing and Reference implementation as the normal participant route. It may disable only canonical continuation/temporal orchestration required by the reference-floor contract.

Record:

- reference-floor status;
- sample validity;
- physical advances;
- nonlinear iterations;
- internal retries;
- headcalc/Jacobian/linear/backtracking counts;
- mass completeness and residual;
- bottom exchange and terminal bottom flux.

### TRANSACTION

Use the current exact FGC44 participant/canonical transaction route with the same origin and prescribed-head forcing.

Record the existing participant and solver/transaction diagnostics.

## Decision

If FLOOR succeeds for the nonzero points while TRANSACTION reproduces failure, localize the divergence to canonical transaction attempt/retry lifecycle rather than the serialized physical solver request.

If FLOOR also fails, the remaining difference lies inside serialized backend model preparation/state materialization before or during physical advance.

If both succeed, reconcile the participant harness because the previously observed failure is no longer reproduced.

No production `src/**` change is allowed in R9.
