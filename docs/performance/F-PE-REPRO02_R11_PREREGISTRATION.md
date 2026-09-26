# F-PE-REPRO02 R11 — serialized corrector-backend lifetime

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R9 established that a fresh serialized reference-floor backend solves all 18 difficult-origin points, whereas the normal transaction route solves only 7/18.

R10 excluded canonical attempt-context capture/restore.

R9 still changes more than one factor at once. In particular, the FLOOR arm creates a fresh serialized backend after FGC44 initialization, while the normal participant uses the long-lived corrector backend initialized before the predictor phase.

## Question

Does serialized corrector-backend/workspace lifetime cause the physical convergence divergence?

## Arms

Use the normal exact FGC44 participant transaction route in both arms. Preserve:

- the same temporal-indicator committed-state type and history;
- the same captured participant origin/checkpoint;
- the same materializer and forcing;
- the same canonical model-certificate transaction policy;
- accepted-trajectory direction request;
- max nonlinear iterations = 48;
- max backtracking = 16;
- minimum step duration = 1e-10 day.

### BASE

Use the existing FGC44 corrector backend, initialized during FGC44 initialization before the predictor is executed.

### FRESH_BACKEND

After predictor initialization and origin capture are complete, create and initialize a new serialized Reference backend and pass that backend to the same participant `trial_from_origin` call.

Do not change committed state, participant checkpoint, transaction policy or forcing.

## Cases

Six difficult PROFILE06 origins at:

- -0.001 cm;
- 0;
- +0.001 cm.

Three fresh-process repetitions per point/arm.

## Measurements

Report:

- participant status;
- solver status;
- nonlinear iterations;
- backtracking attempts;
- temporal certificate availability where reached;
- q and tangent availability on successful trials.

## Decision

If FRESH_BACKEND restores the nonzero failures while BASE reproduces 7/18, backend/workspace lifetime is causally implicated.

If BASE and FRESH_BACKEND are identical, backend initialization timing and fresh workspace are excluded. The R9 split must then be pursued through state type / temporal-history / checkpoint-candidate lifecycle differences.

No production `src/**` change is allowed in R11.
