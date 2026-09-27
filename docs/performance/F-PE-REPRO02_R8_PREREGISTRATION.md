# F-PE-REPRO02 R8 — predictor-history contamination test

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R7 established identity of the active physical corrector request and provider evaluations between the successful direct route and the failing serialized participant route.

The remaining structural difference is process history.

FGC44 executes a predictor solve before the corrector. Predictor and corrector have separate backend/workspace objects, but the Reference implementation still binds into process-global legacy state before each solve.

## Question

Can a prior predictor-like mode-2 solve in the same process change the convergence of a later physically identical mode-5 corrector that uses a fresh solver/workspace object?

## Arms

Use the six difficult PROFILE06 origins and offsets -0.001, 0 and +0.001 cm.

Corrector request is identical in both arms:

- mode 5 prescribed bottom head;
- explicit-flux top;
- max iterations 48;
- max backtracking 16;
- minimum step duration 1e-10 day;
- 1e-12 balance/head tolerances;
- same MvG provider and zero source/sink forcing.

### CLEAN

Bind the corrector request into the serialized legacy context and execute it with a fresh Reference solver/workspace.

### AFTER_PREDICTOR

First execute a predictor-like mode-2 physical solve in the same process:

- same uniform h0 origin;
- top flux = -K(h0);
- prescribed bottom flux = -K(h0);
- same duration and numerical controls;
- separate predictor solver/workspace.

Then rebind the unchanged mode-5 corrector request and execute it with a separate fresh corrector solver/workspace.

## Repetitions

Three fresh processes per case/offset/arm.

## Decision

If CLEAN converges but AFTER_PREDICTOR reproduces the participant failure signature, process-global legacy state is causally implicated and REPRO02 advances to localization of the specific global carrier.

If both arms converge identically, predictor physical-solve history is excluded and the next comparison moves to canonical transaction attempt-context capture/restore and serialized backend lifecycle.

No production source change is allowed in R8.
